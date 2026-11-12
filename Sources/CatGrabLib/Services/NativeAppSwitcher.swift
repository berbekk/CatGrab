import Foundation

/// Системный переключатель приложений (⌘Tab / ⌘⇧Tab) обрабатывается WindowServer как symbolic hotkey
/// и срабатывает даже когда событие поглощено нашим tap'ом. Отключаем его на время, пока
/// CatGrab забирает эти сочетания себе — так же делает AltTab. Возвращаем при остановке tap'а и выходе.
enum NativeAppSwitcher {
    private enum SymbolicHotKey: Int32 {
        case commandTab = 1
        case commandShiftTab = 2
    }

    private typealias SetEnabledFn = @convention(c) (Int32, Bool) -> Int32
    private typealias IsEnabledFn = @convention(c) (Int32) -> Bool

    private static let api: (set: SetEnabledFn, get: IsEnabledFn)? = {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY),
              let setter = dlsym(handle, "CGSSetSymbolicHotKeyEnabled"),
              let getter = dlsym(handle, "CGSIsSymbolicHotKeyEnabled") else {
            return nil
        }
        return (unsafeBitCast(setter, to: SetEnabledFn.self), unsafeBitCast(getter, to: IsEnabledFn.self))
    }()

    private static var ownership = SymbolicHotkeyOwnership()

    /// Отключает системные ⌘Tab / ⌘⇧Tab ровно для тех сочетаний, которые перехватывает CatGrab.
    static func suspend(commandTab: Bool, commandShiftTab: Bool) {
        var wanted: Set<Int32> = []
        if commandTab { wanted.insert(SymbolicHotKey.commandTab.rawValue) }
        if commandShiftTab { wanted.insert(SymbolicHotKey.commandShiftTab.rawValue) }

        update(wanted)
    }

    static func restore() {
        update([])
    }

    private static func update(_ wanted: Set<Int32>) {
        guard let api else { return }
        ownership.update(wanted: wanted, isEnabled: { api.get($0) }, setEnabled: { api.set($0, $1) == 0 })
    }
}

/// Возвращаем только то, что сами успешно отключили. Состояние другого переключателя
/// (например, AltTab) до запуска CatGrab не должно меняться при нашем выходе.
struct SymbolicHotkeyOwnership {
    private(set) var disabledKeys: Set<Int32> = []

    mutating func update(wanted: Set<Int32>, isEnabled: (Int32) -> Bool, setEnabled: (Int32, Bool) -> Bool) {
        for key in disabledKeys.subtracting(wanted) where setEnabled(key, true) {
            disabledKeys.remove(key)
        }
        for key in wanted.subtracting(disabledKeys) where isEnabled(key) && setEnabled(key, false) {
            disabledKeys.insert(key)
        }
    }
}
