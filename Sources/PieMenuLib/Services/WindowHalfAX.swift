import Foundation

/// Устарело: AX к чужим приложениям недоступен в App Sandbox.
enum WindowHalfAX {
    enum Direction {
        case left, right, top, bottom
    }

    @discardableResult
    static func perform(direction: Direction, for pid: pid_t) -> Bool { false }
}

enum WindowHalvesShortcut {
    static func halfDirection(keyCode: Int, modifiers: Int) -> WindowHalfAX.Direction? { nil }
}
