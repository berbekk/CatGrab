import XCTest
@testable import CatGrabLib

final class ConfigManagerTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    @MainActor
    func test_unchangedSaveDoesNotWriteOrRefreshTheTimestamp() async throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        let manager = ConfigManager(configURL: url)
        let original = try Data(contentsOf: url)
        let date = manager.configuration.lastModified
        var unchanged = manager.configuration
        unchanged.lastModified = date.addingTimeInterval(20)
        XCTAssertTrue(manager.save(unchanged))
        XCTAssertEqual(manager.configuration.lastModified, date)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor
    func test_startupDoesNotRewriteAnExistingConfig() async throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        let data = try JSONEncoder().encode(PieConfiguration.defaultConfig)
        try data.write(to: url)
        let manager = ConfigManager(configURL: url)
        XCTAssertNil(manager.persistenceError)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    @MainActor
    func test_legacyMigrationIsSavedOnceAndStableAcrossLaunches() async throws {
        let url = try temporaryDirectory().appendingPathComponent("config.json")
        var legacy = PieConfiguration.defaultConfig
        legacy.menus[0].items[0].action = .unassigned
        legacy.menus[0].items[0].icon = PieMenuItem.legacyUnassignedSFSymbol
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json["schemaVersion"] = 1
        try JSONSerialization.data(withJSONObject: json).write(to: url)
        let first = ConfigManager(configURL: url)
        let migratedBytes = try Data(contentsOf: url)
        let savedHeader = try XCTUnwrap(JSONSerialization.jsonObject(with: migratedBytes) as? [String: Any])
        XCTAssertEqual(savedHeader["schemaVersion"] as? Int, PieConfiguration.currentSchemaVersion)
        XCTAssertNotEqual(first.configuration.menus[0].items[0].icon, PieMenuItem.legacyUnassignedSFSymbol)
        XCTAssertEqual(ConfigManager(configURL: url).configuration, first.configuration)
        XCTAssertEqual(try Data(contentsOf: url), migratedBytes)
    }

    @MainActor
    func test_corruptFileIsPreservedUntilASuccessfulBackup() async throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("config.json")
        let corrupt = Data("{unfinished".utf8)
        try corrupt.write(to: url)
        let manager = ConfigManager(configURL: url)
        XCTAssertNotNil(manager.persistenceError)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        XCTAssertTrue(manager.save(manager.configuration))
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("config.broken-") }
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(backups.first)), corrupt)
        XCTAssertNoThrow(try JSONDecoder().decode(PieConfiguration.self, from: Data(contentsOf: url)))
        XCTAssertNil(manager.persistenceError)
    }

    @MainActor
    func test_backupFailureDoesNotCreateAReplacement() async throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("config.json")
        let original = Data("broken settings".utf8)
        try original.write(to: url)
        let manager = ConfigManager(configURL: url)
        // The original disappears before backup; the save must report failure, not write defaults.
        try FileManager.default.removeItem(at: url)
        XCTAssertFalse(manager.save(manager.configuration))
        XCTAssertNotNil(manager.persistenceError)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func test_failedSaveKeepsChangesForExportAndCanRetry() async throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("config.json")
        let manager = ConfigManager(configURL: url)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try Data([1]).write(to: url.appendingPathComponent("blocker"))
        var changed = manager.configuration
        changed.menus[0].name = "My unsaved menu"
        XCTAssertFalse(manager.save(changed))
        XCTAssertNotNil(manager.persistenceError)
        let exported = directory.appendingPathComponent("backup.json")
        try manager.exportConfiguration(to: exported)
        XCTAssertEqual(try JSONDecoder().decode(PieConfiguration.self, from: Data(contentsOf: exported)).menus[0].name, "My unsaved menu")
        try FileManager.default.removeItem(at: url)
        XCTAssertTrue(manager.save(manager.configuration))
        XCTAssertNil(manager.persistenceError)
        XCTAssertEqual(ConfigManager(configURL: url).configuration.menus[0].name, "My unsaved menu")
    }
}
