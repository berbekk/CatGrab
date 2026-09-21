import XCTest
@testable import CatGrabLib

final class LegacyPieMenuMigrationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to directory: String) throws -> URL {
        let dir = root.appendingPathComponent(directory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: dir.appendingPathComponent("config.json"))
        return dir
    }

    func test_copiesOldConfigAndRewritesFaviconPaths() throws {
        let old = try write(#"{"icon":"file:\/Users\/me\/Library\/Caches\/PieMenu\/favicons\/a.png","b":"Caches/PieMenu/favicons/b.png"}"#, to: "PieMenu")
        let new = root.appendingPathComponent("CatGrab")
        LegacyPieMenuMigration.migrateConfig(from: old, to: new, fileManager: .default)
        let migrated = try String(contentsOf: new.appendingPathComponent("config.json"), encoding: .utf8)
        XCTAssertEqual(migrated, #"{"icon":"file:\/Users\/me\/Library\/Caches\/CatGrab\/favicons\/a.png","b":"Caches/CatGrab/favicons/b.png"}"#)
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.appendingPathComponent("config.json").path))
    }

    func test_neverOverwritesAnExistingConfig() throws {
        let old = try write("old", to: "PieMenu")
        let new = try write("new", to: "CatGrab")
        LegacyPieMenuMigration.migrateConfig(from: old, to: new, fileManager: .default)
        XCTAssertEqual(try String(contentsOf: new.appendingPathComponent("config.json"), encoding: .utf8), "new")
    }

    func test_withoutOldConfigDoesNothing() {
        let new = root.appendingPathComponent("CatGrab")
        LegacyPieMenuMigration.migrateConfig(from: root.appendingPathComponent("PieMenu"), to: new, fileManager: .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: new.path))
    }
}
