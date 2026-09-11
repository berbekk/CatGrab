import Foundation

/// Устарело: AppleScript / System Events недоступны в App Sandbox.
enum SystemEventsKeyScript {
    @discardableResult
    static func sendLockScreenChord() -> Bool { false }

    @discardableResult
    static func sendKeyCode(_ keyCode: Int, appleSymbolicModifiers: Int) -> Bool { false }
}
