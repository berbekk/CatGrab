import AppKit

/// Исполняет действия пунктов пирога в режиме App Sandbox (без AX / CGEvent post).
struct AppLauncher {
    static func execute(item: PieMenuItem, targetPID: pid_t? = nil) {
        switch item.action {
        case .unassigned, .keystroke:
            return
        case .launchApp(let bundleIdentifier):
            launchApp(bundleIdentifier: bundleIdentifier)
        case .openURL(let urlString):
            openURL(urlString)
        case .systemShortcut(let kind):
            MacOSSystemActionRunner.perform(kind)
        case .snippet(let text):
            SnippetInserter.perform(text: text, targetPID: targetPID)
        }
    }

    private static func launchApp(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    private static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
