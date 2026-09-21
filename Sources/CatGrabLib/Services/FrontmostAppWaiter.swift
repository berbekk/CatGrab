import AppKit

/// Ждёт, пока приложение снова станет активным после закрытия меню: нажатия и команды меню
/// уходят в активное приложение. Если не дождались, всё равно выполняет действие — лучше попасть
/// в текущее окно, чем потерять его.
enum FrontmostAppWaiter {
    private static let waitLimit: TimeInterval = 0.5
    private static let pollInterval: TimeInterval = 0.02

    static func wait(for pid: pid_t?, then action: @escaping () -> Void) {
        poll(pid: pid, deadline: Date().addingTimeInterval(waitLimit), then: action)
    }

    private static func poll(pid: pid_t?, deadline: Date, then action: @escaping () -> Void) {
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let pid, front != pid, Date() < deadline else {
            if let pid, front != pid {
                PieLog.launcher.notice("target pid \(pid) not frontmost in time, acting anyway")
            }
            action()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            poll(pid: pid, deadline: deadline, then: action)
        }
    }
}
