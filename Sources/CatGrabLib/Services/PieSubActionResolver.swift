import AppKit
import ApplicationServices

/// Собирает команды для меню «Команды приложения»: свой набор приложения (`AppSubMenu`) или, если его нет,
/// набор по умолчанию из самого меню (`PieConfiguration.defaultAppCommands`).
enum PieSubActionResolver {
    /// Что известно о приложении на главном потоке, до ухода в фоновую очередь.
    struct AppContext {
        let pid: pid_t
        let appName: String
        let canHide: Bool
        let canQuit: Bool
        let language: AppLanguage
    }

    /// Приложения, которые нельзя «завершить» без последствий: Finder без окон — это рабочий стол.
    private static let unquittableBundleIds: Set<String> = ["com.apple.finder"]

    /// Меню приложения меняется редко, а поиск пункта дорогой — держим результат недолго, чтобы повторное
    /// открытие меню было мгновенным. Трогать только на `queue`.
    private static let cacheLifetime: TimeInterval = 20
    private struct ItemKey: Hashable {
        let pid: pid_t
        let path: [String]
    }
    private static var itemCache: [ItemKey: (date: Date, info: AppMenuItemInfo)] = [:]

    /// Все AX-запросы к чужим приложениям идут последовательно здесь: и сборка, и выполнение.
    static let queue = DispatchQueue(label: "CatGrab.SubActions.ax", qos: .userInteractive)

    static func runningApp(bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { $0.activationPolicy == .regular && !$0.isTerminated }
    }

    /// Чьи команды показывать: активного приложения. Если активен сам CatGrab (открыты его настройки),
    /// — того, что было активно до него: иначе хоткей в настройках показывал бы команды самих настроек.
    @MainActor
    static func targetApp() -> NSRunningApplication? {
        let own = Bundle.main.bundleIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != own,
           front.activationPolicy == .regular {
            return front
        }
        return RunningAppsActivationHistory.bundleIdentifierBeforeLastActivation.flatMap(runningApp(bundleIdentifier:))
    }

    /// Отмена запроса, который уже стоит в очереди: пользователь отпустил хоткей раньше, чем команды собрались.
    final class Ticket: @unchecked Sendable {
        private let lock = NSLock()
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func cancel() {
            lock.lock()
            cancelled = true
            lock.unlock()
        }
    }

    /// Асинхронно: AX-запросы к чужому процессу идут по IPC и не должны тормозить меню.
    @MainActor
    @discardableResult
    static func resolve(app: NSRunningApplication, completion: @escaping ([PieSubAction]) -> Void) -> Ticket {
        let ticket = Ticket()
        guard let bundleId = app.bundleIdentifier else {
            completion([])
            return ticket
        }
        let configuration = ConfigManager.shared.configuration
        let context = AppContext(
            pid: app.processIdentifier,
            appName: app.localizedName ?? bundleId,
            canHide: !app.isHidden,
            canQuit: !unquittableBundleIds.contains(bundleId),
            language: configuration.language
        )
        let entries = configuration.appSubMenu(for: bundleId)?.entries ?? configuration.defaultAppCommands
        queue.async {
            guard !ticket.isCancelled else { return }
            let actions = actions(for: entries, context: context)
            DispatchQueue.main.async { completion(actions) }
        }
        return ticket
    }

    /// Найти пункты своего набора в меню приложения заранее, пока пользователь в нём работает: тогда
    /// меню команд откроется по хоткею без задержки на поиск по строке меню.
    @MainActor
    static func prefetch(app: NSRunningApplication) {
        guard let bundleId = app.bundleIdentifier,
              let entries = ConfigManager.shared.configuration.appSubMenu(for: bundleId)?.entries,
              entries.contains(where: { $0.kind == .menuItem }) else { return }
        let pid = app.processIdentifier
        queue.async {
            guard AXIsProcessTrusted() else { return }
            for entry in entries where entry.kind == .menuItem {
                _ = cachedItem(pid: pid, path: entry.menuPath, shortcut: entry.shortcut)
            }
        }
    }

    // MARK: - Сборка (на `queue`)

    /// Недоступные сейчас пункты (выключены, у приложения нет окна, меню поменялось) остаются на своём
    /// месте приглушёнными: пользователь запоминает, где что лежит, и кольцо не должно перестраиваться
    /// от состояния приложения.
    private static func actions(for entries: [AppSubMenuEntry], context: AppContext) -> [PieSubAction] {
        let trusted = AXIsProcessTrusted()
        let needsWindow = entries.contains { $0.kind.needsWindow }
        let window = trusted && needsWindow ? WindowAX.targetWindow(pid: context.pid) : nil
        return entries.enumerated().map { index, entry in
            let available: PieSubAction?
            switch entry.kind {
            case .menuItem:
                if trusted,
                   let info = cachedItem(pid: context.pid, path: entry.menuPath, shortcut: entry.shortcut),
                   info.isEnabled {
                    available = menuAction(AppMenuCommand(info), icon: entry.resolvedIcon, context: context)
                } else {
                    available = nil
                }
            case .hideApp:
                available = context.canHide ? builtIn(.hideApp, context: context, window: nil, icon: entry.icon) : nil
            case .quitApp:
                available = context.canQuit ? builtIn(.quitApp, context: context, window: nil, icon: entry.icon) : nil
            case .minimizeWindow, .toggleFullScreen, .tileLeft, .tileRight, .tileTop, .tileBottom, .fillScreen,
                 .centerWindow, .closeWindow:
                available = builtIn(entry.kind, context: context, window: window, icon: entry.icon)
            }
            return available ?? unavailableAction(entry, index: index, context: context)
        }
    }

    private static func unavailableAction(_ entry: AppSubMenuEntry, index: Int, context: AppContext) -> PieSubAction {
        let title = entry.kind == .menuItem
            ? entry.menuTitle
            : entry.kind.title(appName: context.appName, language: context.language)
        return PieSubAction(
            id: "unavailable:\(index)",
            title: title,
            icon: entry.resolvedIcon,
            shortcut: entry.shortcut?.displayString,
            isDestructive: false,
            kind: .unavailable,
            pid: context.pid
        )
    }

    private static func menuAction(_ command: AppMenuCommand, icon: String, context: AppContext) -> PieSubAction {
        PieSubAction(
            id: "menu:\(command.path.joined(separator: "›"))",
            title: command.title,
            icon: icon,
            shortcut: command.shortcut?.displayString,
            isDestructive: false,
            kind: .menuCommand(command),
            pid: context.pid
        )
    }

    /// Встроенная команда, если она сейчас применима. Команды окна без окна не бывает.
    private static func builtIn(
        _ kind: AppSubMenuEntry.Kind,
        context: AppContext,
        window: AXUIElement?,
        icon: String? = nil
    ) -> PieSubAction? {
        func action(_ actionKind: PieSubAction.Kind, defaultIcon: String? = nil) -> PieSubAction {
            PieSubAction(
                id: kind.rawValue,
                title: kind.title(appName: context.appName, language: context.language),
                icon: icon ?? defaultIcon ?? kind.defaultIcon,
                shortcut: nil,
                isDestructive: kind == .quitApp,
                kind: actionKind,
                pid: context.pid
            )
        }
        switch kind {
        case .menuItem:
            return nil
        case .hideApp:
            return action(.hideApp)
        case .quitApp:
            return action(.quitApp)
        case .minimizeWindow:
            guard let window, WindowAX.canMinimize(window) else { return nil }
            return action(.minimizeWindow(window))
        case .toggleFullScreen:
            guard let window, let isFullScreen = WindowAX.fullScreenState(window) else { return nil }
            return action(
                .toggleFullScreen(window),
                defaultIcon: isFullScreen ? "arrow.down.right.and.arrow.up.left" : nil
            )
        case .tileLeft, .tileRight, .tileTop, .tileBottom, .fillScreen, .centerWindow:
            // Окно в полноэкранном режиме двигать нельзя — его сначала надо из него вывести.
            guard let window, WindowAX.canMoveAndResize(window), WindowAX.fullScreenState(window) != true,
                  let tile = windowTile(for: kind) else { return nil }
            return action(.tileWindow(window, tile))
        case .closeWindow:
            guard let window, WindowAX.canClose(window) else { return nil }
            return action(.closeWindow(window))
        }
    }

    private static func windowTile(for kind: AppSubMenuEntry.Kind) -> WindowTile? {
        switch kind {
        case .tileLeft: return .left
        case .tileRight: return .right
        case .tileTop: return .top
        case .tileBottom: return .bottom
        case .fillScreen: return .fill
        case .centerWindow: return .center
        default: return nil
        }
    }

    /// Сам пункт запоминаем, а доступность спрашиваем каждый раз: она меняется от состояния приложения
    /// (например, «Новая вкладка» без окон выключена), и это один дешёвый запрос.
    private static func cachedItem(pid: pid_t, path: [String], shortcut: MenuShortcut?) -> AppMenuItemInfo? {
        let now = Date()
        let key = ItemKey(pid: pid, path: path)
        itemCache = itemCache.filter { now.timeIntervalSince($0.value.date) < cacheLifetime }
        if let cached = itemCache[key] {
            let element = cached.info.element
            AXUIElementSetMessagingTimeout(element, AppMenuCommandReader.messagingTimeout)
            var enabled: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled) == .success {
                return AppMenuItemInfo(
                    path: cached.info.path,
                    shortcut: cached.info.shortcut,
                    isEnabled: (enabled as? Bool) ?? true,
                    element: element
                )
            }
            // Элемент устарел: приложение пересобрало меню.
            itemCache[key] = nil
        }
        guard let info = AppMenuCommandReader.item(pid: pid, path: path, shortcut: shortcut) else { return nil }
        itemCache[key] = (now, info)
        return info
    }

    /// Смысл этих сочетаний почти везде один, поэтому и значок общий; точное название — в подписи.
    static func icon(for shortcut: MenuShortcut) -> String {
        switch (shortcut.character, shortcut.modifiers) {
        case ("N", []): return "macwindow.badge.plus"
        case ("T", []): return "plus.square.on.square"
        case ("N", .shift): return "plus.circle"
        case ("T", .shift): return "arrow.uturn.backward"
        case ("O", []): return "folder"
        case (",", []): return "gearshape"
        default: return "command"
        }
    }
}

/// Окно приложения через Accessibility: какое трогать и что с ним можно сделать.
enum WindowAX {
    private static let fullScreenAttribute = "AXFullScreen"

    /// Окно, с которым пользователь работал последним: фокусное, иначе главное, иначе первое обычное.
    static func targetWindow(pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, AppMenuCommandReader.messagingTimeout)
        if let focused: AXUIElement = AppMenuCommandReader.copyAttribute(app, kAXFocusedWindowAttribute),
           isStandardWindow(focused) {
            return focused
        }
        if let main: AXUIElement = AppMenuCommandReader.copyAttribute(app, kAXMainWindowAttribute),
           isStandardWindow(main) {
            return main
        }
        let windows: [AXUIElement] = AppMenuCommandReader.copyAttribute(app, kAXWindowsAttribute) ?? []
        return windows.first(where: isStandardWindow)
    }

    private static func isStandardWindow(_ window: AXUIElement) -> Bool {
        AXUIElementSetMessagingTimeout(window, AppMenuCommandReader.messagingTimeout)
        let subrole: String? = AppMenuCommandReader.copyAttribute(window, kAXSubroleAttribute)
        let minimized: Bool = AppMenuCommandReader.copyAttribute(window, kAXMinimizedAttribute) ?? false
        return subrole == kAXStandardWindowSubrole && !minimized
    }

    static func canMinimize(_ window: AXUIElement) -> Bool {
        isSettable(window, kAXMinimizedAttribute)
    }

    static func canMoveAndResize(_ window: AXUIElement) -> Bool {
        isSettable(window, kAXPositionAttribute) && isSettable(window, kAXSizeAttribute)
    }

    /// Рамка окна в координатах Accessibility: начало — левый верхний угол главного экрана, ось Y вниз.
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = AppMenuCommandReader.copyAttribute(window, kAXPositionAttribute),
              let sizeValue: AXValue = AppMenuCommandReader.copyAttribute(window, kAXSizeAttribute) else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Раскладывает окно по рабочей области экрана, на котором оно сейчас.
    /// `screens` — рабочие области всех экранов в координатах Accessibility (см. `accessibilityFrame`).
    @discardableResult
    static func tile(_ window: AXUIElement, _ tile: WindowTile, screens: [CGRect]) -> Bool {
        guard let current = frame(of: window),
              let screen = screenFrame(containing: CGPoint(x: current.midX, y: current.midY), in: screens) else {
            return false
        }
        if tile == .center {
            let target = centeredFrame(current, in: screen)
            return (target.size == current.size || setSize(window, target.size)) && setPosition(window, target.origin)
        }
        let target = tileFrame(tile, in: screen)
        // Размер — до и после сдвига: некоторые приложения не дают вырасти окну, упёршемуся в край экрана,
        // пока оно не сдвинуто, а другие обрезают сдвиг по старому размеру.
        return setSize(window, target.size)
            && setPosition(window, target.origin)
            && setSize(window, target.size)
    }

    /// Окно того же размера посередине рабочей области; если оно больше области — ужимается до неё.
    static func centeredFrame(_ window: CGRect, in screen: CGRect) -> CGRect {
        let size = CGSize(width: min(window.width, screen.width), height: min(window.height, screen.height))
        return CGRect(
            x: (screen.midX - size.width / 2).rounded(),
            y: (screen.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }

    /// Прямоугольник окна для раскладки в рабочей области экрана (координаты Accessibility).
    static func tileFrame(_ tile: WindowTile, in screen: CGRect) -> CGRect {
        let halfWidth = (screen.width / 2).rounded(.down)
        let halfHeight = (screen.height / 2).rounded(.down)
        switch tile {
        case .left: return CGRect(x: screen.minX, y: screen.minY, width: halfWidth, height: screen.height)
        case .right:
            return CGRect(x: screen.minX + halfWidth, y: screen.minY, width: screen.width - halfWidth, height: screen.height)
        // Ось Y в координатах Accessibility направлена вниз: верхняя половина начинается с `minY`.
        case .top: return CGRect(x: screen.minX, y: screen.minY, width: screen.width, height: halfHeight)
        case .bottom:
            return CGRect(x: screen.minX, y: screen.minY + halfHeight, width: screen.width, height: screen.height - halfHeight)
        case .fill: return screen
        // Размер окна знает только `centeredFrame`; без него — вся область.
        case .center: return screen
        }
    }

    /// Экран, где середина окна; если она за пределами всех экранов — ближайший к ней.
    static func screenFrame(containing point: CGPoint, in screens: [CGRect]) -> CGRect? {
        if let screen = screens.first(where: { $0.contains(point) }) { return screen }
        return screens.min { distance(from: point, to: $0) < distance(from: point, to: $1) }
    }

    /// Перевод прямоугольника из координат AppKit (начало — левый нижний угол главного экрана, ось Y вверх)
    /// в координаты Accessibility.
    static func accessibilityFrame(_ appKitFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: appKitFrame.minX,
            y: primaryScreenHeight - appKitFrame.maxY,
            width: appKitFrame.width,
            height: appKitFrame.height
        )
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    private static func setPosition(_ window: AXUIElement, _ point: CGPoint) -> Bool {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return false }
        return AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, axValue) == .success
    }

    private static func setSize(_ window: AXUIElement, _ size: CGSize) -> Bool {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return false }
        return AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, axValue) == .success
    }

    static func canClose(_ window: AXUIElement) -> Bool {
        guard let button: AXUIElement = AppMenuCommandReader.copyAttribute(window, kAXCloseButtonAttribute) else {
            return false
        }
        AXUIElementSetMessagingTimeout(button, AppMenuCommandReader.messagingTimeout)
        return AppMenuCommandReader.copyAttribute(button, kAXEnabledAttribute) ?? true
    }

    /// Текущее состояние полноэкранного режима; `nil` — окно его не поддерживает.
    static func fullScreenState(_ window: AXUIElement) -> Bool? {
        guard isSettable(window, fullScreenAttribute) else { return nil }
        return AppMenuCommandReader.copyAttribute(window, fullScreenAttribute) ?? false
    }

    @discardableResult
    static func close(_ window: AXUIElement) -> Bool {
        guard let button: AXUIElement = AppMenuCommandReader.copyAttribute(window, kAXCloseButtonAttribute) else {
            return false
        }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }

    @discardableResult
    static func minimize(_ window: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success
    }

    @discardableResult
    static func toggleFullScreen(_ window: AXUIElement) -> Bool {
        let current: Bool = AppMenuCommandReader.copyAttribute(window, fullScreenAttribute) ?? false
        let value: CFBoolean = current ? kCFBooleanFalse : kCFBooleanTrue
        return AXUIElementSetAttributeValue(window, fullScreenAttribute as CFString, value) == .success
    }

    private static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else { return false }
        return settable.boolValue
    }
}
