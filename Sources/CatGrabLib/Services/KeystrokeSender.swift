import AppKit

/// Отправляет сочетание клавиш из пункта меню приложению, которое было активным до открытия меню.
/// Требует разрешение «Универсальный доступ» — без него macOS молча отбрасывает синтетические события.
enum KeystrokeSender {
    /// Клавиши, у которых настоящие события несут `maskSecondaryFn` (и у стрелок — `maskNumericPad`).
    /// Приложения на движке Firefox, в том числе Zen, без этих флагов могут не распознать ⌘⌥← / ⌘⌥→.
    private static let arrowKeyCodes: Set<Int> = [123, 124, 125, 126]
    private static let functionKeyCodes: Set<Int> = [115, 116, 117, 119, 121]

    /// `modifiers` хранятся в конфиге как маска `CGEventFlags`.
    static func perform(keyCode: Int, modifiers: Int, targetPID: pid_t?) {
        guard keyCode != 0 || modifiers != 0 else { return }
        guard AXIsProcessTrusted() else {
            PieLog.launcher.error("keystroke skipped: Accessibility permission not granted")
            return
        }
        // Нажатия уходят в активное приложение, поэтому ждём, пока фокус действительно вернётся к нему.
        FrontmostAppWaiter.wait(for: targetPID) {
            post(keyCode: keyCode, modifiers: modifiers)
        }
    }

    private static func post(keyCode: Int, modifiers: Int) {
        var flags = CGEventFlags(rawValue: UInt64(modifiers))
        if arrowKeyCodes.contains(keyCode) {
            flags.insert([.maskSecondaryFn, .maskNumericPad])
        } else if functionKeyCodes.contains(keyCode) {
            flags.insert(.maskSecondaryFn)
        }

        // Своё состояние источника: физически зажатые клавиши (например, модификаторы хоткея меню)
        // не подмешиваются к флагам отправляемого сочетания.
        let source = CGEventSource(stateID: .privateState)
        let virtualKey = CGKeyCode(keyCode)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            PieLog.launcher.error("keystroke: failed to create CGEvent for key \(keyCode)")
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgSessionEventTap)
        usleep(Timings.syntheticKeystrokeSessionGapMicroseconds)
        up.post(tap: .cgSessionEventTap)
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        PieLog.launcher.notice("keystroke sent: key=\(keyCode) flags=\(flags.rawValue) front=\(front, privacy: .public)")
    }
}
