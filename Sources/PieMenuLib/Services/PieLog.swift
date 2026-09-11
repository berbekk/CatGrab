import Foundation
import os.log

/// Единая точка логирования для PieMenu. Обёртка над `os.Logger` с общим subsystem,
/// чтобы все категории были видны в Console.app под фильтром `subsystem:PieMenu`.
///
/// Использование:
/// ```
/// PieLog.config.error("failed to write: \(error.localizedDescription, privacy: .public)")
/// PieLog.hotkey.debug("captured code=\(code)")
/// ```
enum PieLog {
    /// Subsystem берётся из bundle id, с fallback на стабильный идентификатор,
    /// чтобы логирование работало и в SwiftPM‑билдах/тестах без Info.plist.
    static let subsystem: String = Bundle.main.bundleIdentifier ?? "com.piemenu.app"

    static let config = Logger(subsystem: subsystem, category: "config")
    static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    static let launcher = Logger(subsystem: subsystem, category: "launcher")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
    static let window = Logger(subsystem: subsystem, category: "window")
    static let system = Logger(subsystem: subsystem, category: "system")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
