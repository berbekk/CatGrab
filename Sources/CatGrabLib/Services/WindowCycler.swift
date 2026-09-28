import AppKit
import ApplicationServices

/// Следующее окно приложения, которое уже на переднем плане, — как ⌘`, только из сектора меню.
/// Выбрали сектор «Safari», а Safari и так впереди: вместо того чтобы ничего не делать,
/// CatGrab выводит вперёд следующее окно Safari на этом рабочем столе.
///
/// Поднимается самое дальнее окно, а не второе сверху: иначе повторные вызовы переключали бы
/// два верхних окна туда-обратно, а до третьего не доходили. С самым дальним — обход по кругу.
/// Окна с других рабочих столов и свёрнутые не участвуют, как и у ⌘`.
enum WindowCycler {
    enum Outcome: Equatable {
        /// Поднято следующее окно.
        case raised
        /// На этом рабочем столе одно окно — переключать не на что.
        case singleWindow
        /// Обычных окон нет: пусть приложение само откроет новое, как по щелчку в Dock.
        case noWindows
        /// Нет «Универсального доступа» — окна не прочитать.
        case notTrusted
    }

    /// AX-запросы к чужому процессу идут по IPC: только не на главном потоке.
    static let queue = DispatchQueue(label: "CatGrab.WindowCycler.ax", qos: .userInteractive)

    private static let messagingTimeout: Float = 0.25

    private typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    /// CGWindowID по AX-элементу окна — связывает окно из списка WindowServer с его AX-представлением.
    private static let axGetWindow: AXGetWindowFn? = {
        let path = "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices"
        guard let handle = dlopen(path, RTLD_LAZY), let pointer = dlsym(handle, "_AXUIElementGetWindow") else { return nil }
        return unsafeBitCast(pointer, to: AXGetWindowFn.self)
    }()

    /// Какое из окон поднять: самое дальнее из тех, что сейчас на экране. `windowIDs` — окна
    /// приложения по Accessibility, `zOrder` — окна на экране сверху вниз (WindowServer).
    /// `nil` — видимых окон меньше двух.
    static func indexToRaise(windowIDs: [CGWindowID?], zOrder: [CGWindowID]) -> Int? {
        var depth: [CGWindowID: Int] = [:]
        for (position, id) in zOrder.enumerated() where depth[id] == nil {
            depth[id] = position
        }
        let visible = windowIDs.enumerated().compactMap { index, id -> (index: Int, depth: Int)? in
            guard let id, let d = depth[id] else { return nil }
            return (index, d)
        }
        guard visible.count > 1 else { return nil }
        return visible.max { $0.depth < $1.depth }?.index
    }

    /// Вызывать на `queue`. Блокирует на время AX-запросов (каждый не дольше `messagingTimeout`).
    static func cycle(pid: pid_t) -> Outcome {
        guard AXIsProcessTrusted() else { return .notTrusted }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        var value: CFTypeRef?
        let windows: [AXUIElement]
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success {
            windows = (value as? [AXUIElement] ?? []).filter(isStandardVisibleWindow)
        } else {
            windows = []
        }
        guard !windows.isEmpty else { return .noWindows }

        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let zOrder = onScreen.compactMap { info -> CGWindowID? in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            return info[kCGWindowNumber as String] as? CGWindowID
        }
        guard let index = indexToRaise(windowIDs: windows.map(windowID), zOrder: zOrder) else {
            return .singleWindow
        }
        let target = windows[index]
        AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, target)
        AXUIElementPerformAction(target, kAXRaiseAction as CFString)
        return .raised
    }

    private static func windowID(_ window: AXUIElement) -> CGWindowID? {
        guard let axGetWindow else { return nil }
        var id: CGWindowID = 0
        guard axGetWindow(window, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// Обычное окно документа, не свёрнутое, — не панель, не диалог и не служебное окно.
    private static func isStandardVisibleWindow(_ window: AXUIElement) -> Bool {
        AXUIElementSetMessagingTimeout(window, messagingTimeout)
        var subrole: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subrole)
        guard (subrole as? String) == kAXStandardWindowSubrole else { return false }
        var minimized: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
        return (minimized as? Bool) != true
    }
}
