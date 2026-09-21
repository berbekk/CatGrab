import Foundation

/// Приложение раньше называлось PieMenu (`com.piemenu.desktop`). При первом запуске под новым именем
/// переносим то, что пользователь уже настроил: конфиг, кэш фавиконок и настройки из UserDefaults.
/// Переносим, только пока у нового имени своего нет, а старые файлы не трогаем — можно откатиться.
public enum LegacyPieMenuMigration {
    static let legacyBundleIdentifier = "com.piemenu.desktop"
    static let legacyFolderName = "PieMenu"
    static let folderName = "CatGrab"

    public static func run() {
        let fileManager = FileManager.default
        migrateUserDefaults()
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            copyIfMissing(
                from: caches.appendingPathComponent("\(legacyFolderName)/favicons"),
                to: caches.appendingPathComponent("\(folderName)/favicons"),
                fileManager: fileManager
            )
        }
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            migrateConfig(
                from: appSupport.appendingPathComponent(legacyFolderName),
                to: appSupport.appendingPathComponent(folderName),
                fileManager: fileManager
            )
        }
    }

    /// Иконки-фавиконки хранятся в конфиге абсолютными путями к кэшу — переписываем их на новую папку.
    /// `JSONEncoder` экранирует `/`, поэтому в файле встречаются оба написания.
    static func migrateConfig(from oldDirectory: URL, to newDirectory: URL, fileManager: FileManager) {
        let oldConfig = oldDirectory.appendingPathComponent("config.json")
        let newConfig = newDirectory.appendingPathComponent("config.json")
        guard !fileManager.fileExists(atPath: newConfig.path),
              let data = try? Data(contentsOf: oldConfig),
              var text = String(data: data, encoding: .utf8) else { return }
        text = text
            .replacingOccurrences(of: "Caches/\(legacyFolderName)/favicons/", with: "Caches/\(folderName)/favicons/")
            .replacingOccurrences(of: "Caches\\/\(legacyFolderName)\\/favicons\\/", with: "Caches\\/\(folderName)\\/favicons\\/")
        do {
            try fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
            try Data(text.utf8).write(to: newConfig, options: .atomic)
        } catch {
            PieLog.config.error("legacy config migration failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func copyIfMissing(from source: URL, to destination: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) else { return }
        try? fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fileManager.copyItem(at: source, to: destination)
    }

    private static func migrateUserDefaults() {
        guard let identifier = Bundle.main.bundleIdentifier, identifier != legacyBundleIdentifier else { return }
        let defaults = UserDefaults.standard
        guard defaults.persistentDomain(forName: identifier)?.isEmpty ?? true,
              let legacy = defaults.persistentDomain(forName: legacyBundleIdentifier), !legacy.isEmpty else { return }
        defaults.setPersistentDomain(legacy, forName: identifier)
    }
}
