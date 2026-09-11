import AppKit
import Foundation

/// Перезапуск приложения: WindowServer применяет права «Мониторинг ввода» к event tap'ам
/// только для нового процесса (в Системных настройках ровно поэтому есть «Завершить и открыть»).
enum AppRelauncher {
    @MainActor
    static func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
