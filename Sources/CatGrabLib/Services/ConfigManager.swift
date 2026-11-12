import Foundation
import Combine

extension Notification.Name {
    static let configurationDidChange = Notification.Name("CatGrab.configurationDidChange")
}

/// Локальное хранилище конфигурации (Application Support).
///
/// iCloud KVS отключён для Mac App Store (sandbox без ubiquity entitlement).
@MainActor
final class ConfigManager: ObservableObject {
    private struct SchemaHeader: Decodable {
        let schemaVersion: Int?
    }
    static let shared = ConfigManager()

    private let configURL: URL
    private let configSubject: CurrentValueSubject<PieConfiguration, Never>
    @Published private(set) var persistenceError: Error?
    private var needsUnreadableBackup = false

    /// Текущая конфигурация. Чтение и запись — с MainActor.
    private(set) var configuration: PieConfiguration {
        didSet {
            configSubject.send(configuration)
        }
    }

    /// Reactive‑publisher, который эмитит текущую конфигурацию при подписке и каждое обновление.
    var configurationPublisher: AnyPublisher<PieConfiguration, Never> {
        configSubject.eraseToAnyPublisher()
    }

    var localConfigURL: URL { configURL }

    /// Cloud sync отключён в App Store-сборке.
    var isCloudStorageAvailable: Bool { false }

    /// Другая папка конфига — чтобы посмотреть на чистую установку, не трогая свои меню
    /// (`scripts/run-fresh-install.sh`).
    static let configDirectoryEnvironmentKey = "CATGRAB_CONFIG_DIR"

    private convenience init() {
        // ~/Library/Application Support существует всегда, но падать из-за этого при запуске незачем:
        // домашний каталог — корректный запасной вариант.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let overrideDir = ProcessInfo.processInfo.environment[Self.configDirectoryEnvironmentKey]
            .flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        let appDir = overrideDir ?? appSupport.appendingPathComponent("CatGrab")
        self.init(configURL: appDir.appendingPathComponent("config.json"), makeInitialConfig: { .firstLaunchConfig() })
    }

    /// Отдельный URL позволяет проверять сохранение, не затрагивая настройки пользователя.
    /// `makeInitialConfig` — что получает человек без файла настроек (первый запуск).
    init(configURL: URL, makeInitialConfig: () -> PieConfiguration = { .defaultConfig }) {
        self.configURL = configURL
        var localConfig: PieConfiguration?
        var loadError: Error?
        var needsMigration = false
        do {
            let data = try Data(contentsOf: configURL)
            let header = try JSONDecoder().decode(SchemaHeader.self, from: data)
            needsMigration = (header.schemaVersion ?? 0) < PieConfiguration.currentSchemaVersion
            localConfig = try JSONDecoder().decode(PieConfiguration.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // Первый запуск: файла ещё нет.
        } catch {
            loadError = error
        }
        let resolved = Self.normalized(localConfig ?? makeInitialConfig())
        self.configuration = resolved
        self.configSubject = CurrentValueSubject(resolved)
        self.persistenceError = loadError
        self.needsUnreadableBackup = loadError != nil
        // Актуальный файл не переписываем при запуске. Миграции сохраняем один раз, иначе
        // случайные значки старых меню менялись бы при каждом запуске. Повреждённый оригинал заменяем
        // только после успешного резервного копирования, даже если ошибка была в правах доступа.
        if loadError == nil, localConfig == nil || needsMigration || localConfig != resolved { writeLocal(resolved) }
    }

    @discardableResult
    func save(_ config: PieConfiguration) -> Bool {
        var toSave = Self.normalized(config)
        toSave.lastModified = configuration.lastModified
        let changed = configuration != toSave
        guard changed || persistenceError != nil else { return true }
        if changed {
            toSave.lastModified = Date()
            configuration = toSave
        }
        let saved = writeLocal(toSave)
        if changed { NotificationCenter.default.post(name: .configurationDidChange, object: nil) }
        return saved
    }

    func reload() {
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(PieConfiguration.self, from: data)
            let normalized = Self.normalized(config)
            persistenceError = nil
            needsUnreadableBackup = false
            guard configuration != normalized else { return }
            configuration = normalized
            NotificationCenter.default.post(name: .configurationDidChange, object: nil)
        } catch {
            PieLog.config.error("reload failed: \(String(describing: error), privacy: .public)")
        }
    }

    @discardableResult
    func restoreFromCloud() -> Bool {
        false
    }

    func exportConfiguration(to destinationURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(configuration)
        try data.write(to: destinationURL, options: .atomic)
    }

    func importConfiguration(from sourceURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        let config = try JSONDecoder().decode(PieConfiguration.self, from: data)
        if !save(config), let persistenceError { throw persistenceError }
    }

    @discardableResult
    private func writeLocal(_ config: PieConfiguration) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(config)
            try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if needsUnreadableBackup {
                try Self.backUpUnreadableConfig(at: configURL)
                needsUnreadableBackup = false
            }
            try data.write(to: configURL, options: .atomic)
            persistenceError = nil
            return true
        } catch {
            persistenceError = error
            PieLog.config.error("writeLocal failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    private static func backUpUnreadableConfig(at url: URL) throws {
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("config.broken-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: backupURL)
        PieLog.config.error("config unreadable, backup saved: \(backupURL.path, privacy: .public)")
    }

    private static func normalized(_ config: PieConfiguration) -> PieConfiguration {
        var c = config
        c.ensureDynamicMenusInvariant()
        PieConfigurationMigrator.migrate(&c)
        return c
    }
}
