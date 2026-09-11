import Foundation

/// Системный переключатель приложений (⌘Tab / ⌘⇧Tab) обрабатывается WindowServer как symbolic hotkey
/// и срабатывает даже когда событие поглощено нашим tap'ом. Отключаем его на время, пока
/// PieMenu забирает эти сочетания себе — так же делает AltTab. Возвращаем при остановке tap'а и выходе.
enum NativeAppSwitcher {
    private enum SymbolicHotKey: Int32 {
        case commandTab = 1
        case commandShiftTab = 2
    }

    private typealias SetEnabledFn = @convention(c) (Int32, Bool) -> Int32

    private static let setEnabled: SetEnabledFn? = {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "CGSSetSymbolicHotKeyEnabled") else {
            return nil
        }
        return unsafeBitCast(symbol, to: SetEnabledFn.self)
    }()

    private static var disabledKeys: Set<Int32> = []

    /// Отключает системные ⌘Tab / ⌘⇧Tab ровно для тех сочетаний, которые перехватывает PieMenu.
    static func suspend(commandTab: Bool, commandShiftTab: Bool) {
        var wanted: Set<Int32> = []
        if commandTab { wanted.insert(SymbolicHotKey.commandTab.rawValue) }
        if commandShiftTab { wanted.insert(SymbolicHotKey.commandShiftTab.rawValue) }

        for key in disabledKeys.subtracting(wanted) { apply(key, enabled: true) }
        for key in wanted.subtracting(disabledKeys) { apply(key, enabled: false) }
        disabledKeys = wanted
    }

    static func restore() {
        for key in disabledKeys { apply(key, enabled: true) }
        disabledKeys = []
    }

    private static func apply(_ key: Int32, enabled: Bool) {
        _ = setEnabled?(key, enabled)
    }
}
