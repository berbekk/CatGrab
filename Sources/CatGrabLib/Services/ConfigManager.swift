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
    static let shared = ConfigManager()

    private let configURL: URL
    private let configSubject: CurrentValueSubject<PieConfiguration, Never>

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

    private init() {
        // ~/Library/Application Support существует всегда, но падать из-за этого при запуске незачем:
        // домашний каталог — корректный запасной вариант.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let appDir = appSupport.appendingPathComponent("CatGrab")
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            PieLog.config.error("failed to create config dir: \(String(describing: error), privacy: .public)")
        }
        configURL = appDir.appendingPathComponent("config.json")

        let localData = try? Data(contentsOf: configURL)
        let localConfig = localData.flatMap(Self.decodeConfig)
        if localData != nil, localConfig == nil {
            // Файл есть, но не читается: не затираем его дефолтом молча — сохраняем копию рядом.
            Self.backUpUnreadableConfig(at: configURL)
        }
        let resolved = Self.normalized(localConfig ?? .defaultConfig)

        self.configuration = resolved
        self.configSubject = CurrentValueSubject(resolved)
        writeLocal(resolved)
    }

    func save(_ config: PieConfiguration) {
        var toSave = Self.normalized(config)
        toSave.lastModified = Date()
        guard configuration != toSave else { return }
        configuration = toSave
        writeLocal(toSave)
        NotificationCenter.default.post(name: .configurationDidChange, object: nil)
    }

    func reload() {
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(PieConfiguration.self, from: data)
            configuration = Self.normalized(config)
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
        save(config)
    }

    private func writeLocal(_ config: PieConfiguration) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            PieLog.config.error("writeLocal failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func backUpUnreadableConfig(at url: URL) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("config.broken-\(stamp).json")
        do {
            try FileManager.default.copyItem(at: url, to: backupURL)
            PieLog.config.error("config unreadable, backup saved: \(backupURL.path, privacy: .public)")
        } catch {
            PieLog.config.error("config backup failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func decodeConfig(from data: Data) -> PieConfiguration? {
        do {
            return try JSONDecoder().decode(PieConfiguration.self, from: data)
        } catch {
            PieLog.config.error("decodeConfig failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private static func normalized(_ config: PieConfiguration) -> PieConfiguration {
        var c = config
        c.ensureDynamicMenusInvariant()
        PieConfigurationMigrator.migrate(&c)
        return c
    }
}
