import AppKit
import Foundation

/// Системные действия через публичные API (NSWorkspace), без osascript / CGEvent.
enum MacOSSystemActionRunner {
    static func perform(_ kind: MacOSSystemActionKind) {
        guard kind.isAvailableInAppStore else { return }
        switch kind {
        case .missionControl:
            openApplication(at: "/System/Applications/Mission Control.app")
        case .startScreenSaver:
            openApplication(at: "/System/Library/CoreServices/ScreenSaverEngine.app")
        case .applicationWindows, .quickNote, .displaySleep, .lockScreen:
            break
        }
    }

    private static func openApplication(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
