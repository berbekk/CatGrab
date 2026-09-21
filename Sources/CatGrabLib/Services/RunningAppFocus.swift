import AppKit

/// Выводит вперёд уже запущенное приложение так же, как ⌘Tab: вместе с переходом в пространство
/// (Space), где лежит его окно, — в том числе в полноэкранное.
///
/// `NSWorkspace.openApplication` и `NSRunningApplication.activate` из CatGrab на macOS 14+ проходят
/// через «кооперативную» активацию: CatGrab — фоновое приложение (LSUIElement), а окно меню его
/// не активирует, поэтому система делает целевое приложение активным, но рабочий стол не переключает.
/// Полноэкранный браузер в соседнем пространстве так и остаётся недосягаемым.
///
/// Если же попросить WindowServer вывести вперёд конкретное окно, он сам переходит в его пространство.
/// Это приватный SkyLight — так работают AltTab и подобные переключатели, и так же проект уже отключает
/// системный ⌘Tab в `NativeAppSwitcher`. Если символы недоступны или окна нет, `focus` возвращает `false`,
/// и вызывающий код откатывается на обычный запуск через Launch Services.
enum RunningAppFocus {
    private typealias SetFrontProcessFn = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32
    ) -> CGError
    private typealias PostEventRecordFn = @convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>
    ) -> CGError
    private typealias GetProcessForPIDFn = @convention(c) (
        pid_t, UnsafeMutablePointer<ProcessSerialNumber>
    ) -> OSStatus

    /// `kCPSUserGenerated`: WindowServer считает запрос действием пользователя, как клик или ⌘Tab.
    private static let userGeneratedMode: UInt32 = 0x200

    /// Окна меньше этого — служебные (невидимые окна браузеров, панели-заглушки, квадрат 64×64 у Терминала),
    /// фокусировать их незачем.
    static let minimumWindowSide: CGFloat = 100

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let applicationServices = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
        RTLD_LAZY
    )

    private static let setFrontProcess: SetFrontProcessFn? = symbol("_SLPSSetFrontProcessWithOptions", in: skyLight)
    private static let postEventRecord: PostEventRecordFn? = symbol("SLPSPostEventRecordTo", in: skyLight)
    /// В Swift помечен недоступным (устарел в 10.9), но в системе есть и нужен SkyLight для адресации процесса.
    private static let getProcessForPID: GetProcessForPIDFn? = symbol("GetProcessForPID", in: applicationServices)

    private typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias AXCreateWithRemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?
    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias SpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?

    /// CGWindowID по AX-элементу окна — связывает окно из списка WindowServer с его AX-представлением.
    private static let axGetWindow: AXGetWindowFn? = symbol("_AXUIElementGetWindow", in: applicationServices)
    /// AX-элемент по «удалённому токену»: так находятся окна в других пространствах, которых нет в `kAXWindows`.
    private static let axCreateWithRemoteToken: AXCreateWithRemoteTokenFn? = symbol(
        "_AXUIElementCreateWithRemoteToken",
        in: applicationServices
    )
    private static let mainConnection: MainConnectionFn? = symbol("SLSMainConnectionID", in: skyLight)
    private static let spacesForWindows: SpacesForWindowsFn? = symbol("SLSCopySpacesForWindows", in: skyLight)
    private typealias ManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private static let managedDisplaySpaces: ManagedDisplaySpacesFn? = symbol("SLSCopyManagedDisplaySpaces", in: skyLight)

    /// AX-запросы к чужому процессу идут по IPC; держим их вне главного потока, чтобы меню не подвисало.
    private static let accessibilityQueue = DispatchQueue(label: "CatGrab.RunningAppFocus.ax", qos: .userInteractive)
    /// Сколько id перебирать в поиске окна из другого пространства (столько же берёт AltTab).
    private static let remoteTokenSearchLimit: UInt64 = 1000

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    /// Выводит вперёд самое верхнее обычное окно приложения и переключает на его пространство.
    /// `false` — окна нет (например, у браузера закрыты все окна) или приватный API недоступен.
    @discardableResult
    static func focus(_ app: NSRunningApplication) -> Bool {
        let bundleID = app.bundleIdentifier ?? "?"
        guard let setFrontProcess, let getProcessForPID else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): SkyLight symbols unavailable")
            return false
        }

        let windowInfo = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        guard let windowID = frontmostWindowID(in: windowInfo, ownerPID: app.processIdentifier) else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): no eligible window")
            return false
        }

        var psn = ProcessSerialNumber()
        let psnStatus = getProcessForPID(app.processIdentifier, &psn)
        guard psnStatus == noErr else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): GetProcessForPID failed \(psnStatus)")
            return false
        }

        if app.isHidden {
            app.unhide()
        }
        let result = setFrontProcess(&psn, windowID, userGeneratedMode)
        guard result == .success else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): SLPSSetFrontProcess failed \(result.rawValue)")
            return false
        }
        makeKeyWindow(windowID, psn: &psn)
        let pid = app.processIdentifier
        accessibilityQueue.async {
            raiseWindow(windowID, ownerPID: pid, bundleID: bundleID)
        }
        return true
    }

    /// SkyLight делает процесс активным, но окно в другом пространстве само не показывается: рабочий
    /// стол остаётся на месте. Просим приложение через Accessibility поднять окно — AppKit в ответ
    /// выводит его вперёд и переходит в его пространство, в том числе полноэкранное.
    private static func raiseWindow(_ windowID: CGWindowID, ownerPID: pid_t, bundleID: String) {
        guard AXIsProcessTrusted() else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): AX not trusted, skip raise")
            return
        }
        let axApp = AXUIElementCreateApplication(ownerPID)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        let windows = axWindows(of: axApp)

        // Все окна свёрнуты в Dock — разворачиваем последнее, как Dock по клику на иконку. Выбранное выше
        // окно WindowServer тут не помогает: свёрнутые окна в его списке без пометки, а первым в нём бывает
        // служебное окно приложения (у Терминала — квадрат 64×64), которого нет среди окон Accessibility.
        if !windows.contains(where: { isStandardWindow($0) && !isMinimized($0) }),
           let minimized = windows.first(where: { isStandardWindow($0) && isMinimized($0) }) {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): restoring minimized window")
            AXUIElementSetAttributeValue(minimized, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(minimized, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(minimized, kAXRaiseAction as CFString)
            return
        }

        let found = windows.first { cgWindowID(of: $0) == windowID }
            ?? axWindowByRemoteToken(ownerPID: ownerPID, matching: windowID)
        guard var window = found else {
            switchSpaceWithSystemShortcut(toWindow: windowID, bundleID: bundleID)
            return
        }
        // Выбрано свёрнутое окно, а рядом есть обычное — показываем обычное: «поднять» свёрнутое окно
        // значит только сделать его главным, на экране ничего не появится.
        if isMinimized(window), let visible = windows.first(where: { isStandardWindow($0) && !isMinimized($0) }) {
            window = visible
        }
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        let raise = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if raise != .success {
            switchSpaceWithSystemShortcut(toWindow: windowID, bundleID: bundleID)
        }
    }

    // MARK: - Запасной путь: системные «На один рабочий стол влево/вправо»

    /// Symbolic hotkeys Mission Control: id, клавиша и модификаторы по умолчанию (⌃← / ⌃→; `0x840000` — Control и Fn,
    /// именно так macOS хранит стрелки в `com.apple.symbolichotkeys`).
    private enum SpaceShortcut: Int {
        case moveLeft = 79
        case moveRight = 81

        var defaultKeyCode: CGKeyCode { self == .moveLeft ? 123 : 124 }
        static let defaultFlags: UInt64 = 0x840000
    }

    /// Некоторые приложения (браузеры на движке Firefox, например Zen) не отдают через Accessibility окна
    /// из других пространств, и поднять такое окно нечем. Тогда переключаем рабочий стол сами — теми же
    /// системными сочетаниями, что нажал бы пользователь, по одному шагу до пространства окна. Попав в
    /// полноэкранное пространство, macOS сама делает его приложение активным.
    private static func switchSpaceWithSystemShortcut(toWindow windowID: CGWindowID, bundleID: String) {
        guard let steps = spaceSteps(toWindow: windowID), steps != 0 else { return }
        let shortcut: SpaceShortcut = steps < 0 ? .moveLeft : .moveRight
        guard let (keyCode, flags) = configuredKey(for: shortcut) else {
            PieLog.launcher.notice("focus \(bundleID, privacy: .public): space shortcut \(shortcut.rawValue) disabled")
            return
        }
        PieLog.launcher.notice("focus \(bundleID, privacy: .public): switching space by \(steps) step(s) via shortcut")
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<abs(steps) {
            for isDown in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
                event.flags = CGEventFlags(rawValue: flags)
                event.post(tap: .cghidEventTap)
            }
            // Dock обрабатывает шаги по очереди; небольшая пауза, чтобы нажатия не слиплись.
            usleep(60_000)
        }
    }

    /// Сколько шагов (со знаком) от текущего пространства дисплея до пространства окна. `nil` — окно
    /// не принадлежит ни одному пространству или порядок пространств узнать не удалось.
    private static func spaceSteps(toWindow windowID: CGWindowID) -> Int? {
        guard let mainConnection, let spacesForWindows, let managedDisplaySpaces else { return nil }
        let connection = mainConnection()
        let windowSpaces = spacesForWindows(connection, 7, [NSNumber(value: windowID)] as CFArray)?
            .takeRetainedValue() as? [NSNumber] ?? []
        guard let windowSpace = windowSpaces.first?.uint64Value,
              let displays = managedDisplaySpaces(connection)?.takeRetainedValue() as? [[String: Any]] else { return nil }
        for display in displays {
            let ordered = (display["Spaces"] as? [[String: Any]] ?? [])
                .compactMap { ($0["ManagedSpaceID"] as? NSNumber)?.uint64Value }
            guard let target = ordered.firstIndex(of: windowSpace),
                  let currentID = ((display["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? NSNumber)?.uint64Value,
                  let current = ordered.firstIndex(of: currentID) else { continue }
            return target - current
        }
        return nil
    }

    /// Клавиша и модификаторы сочетания из системных настроек; `nil`, если пользователь его выключил.
    private static func configuredKey(for shortcut: SpaceShortcut) -> (CGKeyCode, UInt64)? {
        let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys") as? [String: Any]
        guard let entry = hotkeys?[String(shortcut.rawValue)] as? [String: Any] else {
            return (shortcut.defaultKeyCode, SpaceShortcut.defaultFlags)
        }
        if let enabled = entry["enabled"] as? Bool, !enabled {
            return nil
        }
        let parameters = (entry["value"] as? [String: Any])?["parameters"] as? [NSNumber]
        guard let parameters, parameters.count >= 3 else {
            return (shortcut.defaultKeyCode, SpaceShortcut.defaultFlags)
        }
        return (CGKeyCode(parameters[1].uint16Value), parameters[2].uint64Value)
    }

    private static func isMinimized(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success else { return false }
        return (value as? Bool) == true
    }

    /// Обычное окно документа — не панель, не диалог и не служебное окно.
    private static func isStandardWindow(_ window: AXUIElement) -> Bool {
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
        return (subrole as? String) == kAXStandardWindowSubrole
    }

    /// Окна приложения по Accessibility, сверху вниз; свёрнутые тоже здесь, с `AXMinimized`.
    private static func axWindows(of axApp: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    /// Окна из других пространств приложения часто не отдают в `kAXWindows`. Токен элемента —
    /// 20 байт: pid, 0, сигнатура `coco` и порядковый id элемента; перебираем id, пока не совпадёт окно.
    private static func axWindowByRemoteToken(ownerPID: pid_t, matching windowID: CGWindowID) -> AXUIElement? {
        guard let axCreateWithRemoteToken else { return nil }
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: ownerPID) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })
        for elementID in 0..<remoteTokenSearchLimit {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
            guard let element = axCreateWithRemoteToken(token as CFData)?.takeRetainedValue() else { continue }
            if cgWindowID(of: element) == windowID {
                return element
            }
        }
        return nil
    }

    private static func cgWindowID(of element: AXUIElement) -> CGWindowID? {
        guard let axGetWindow else { return nil }
        var windowID: CGWindowID = 0
        guard axGetWindow(element, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    /// Самое верхнее обычное окно процесса. `CGWindowListCopyWindowInfo` отдаёт окна сверху вниз по всем
    /// пространствам, поэтому первое подходящее — то, с которым пользователь работал последним.
    /// Нужны только номер, владелец, слой, прозрачность и рамка — разрешение на запись экрана для них не требуется.
    static func frontmostWindowID(in windowInfo: [[String: Any]], ownerPID: pid_t) -> CGWindowID? {
        for window in windowInfo {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == ownerPID,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let number = window[kCGWindowNumber as String] as? CGWindowID else { continue }
            if let alpha = window[kCGWindowAlpha as String] as? Double, alpha <= 0 { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.width >= minimumWindowSide,
                  bounds.height >= minimumWindowSide else { continue }
            return number
        }
        return nil
    }

    /// Делает выбранное окно ключевым внутри приложения: без этого фокус клавиатуры может остаться
    /// на другом окне того же приложения. Формат записи — тот же, что у AltTab.
    private static func makeKeyWindow(_ windowID: CGWindowID, psn: inout ProcessSerialNumber) {
        guard let postEventRecord else { return }
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { raw in
            for (offset, byte) in raw.enumerated() {
                bytes[0x3c + offset] = byte
            }
        }
        for index in 0x20..<0x30 {
            bytes[index] = 0xff
        }
        for phase: UInt8 in [0x01, 0x02] {
            bytes[0x08] = phase
            bytes.withUnsafeMutableBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                _ = postEventRecord(&psn, base)
            }
        }
    }
}
