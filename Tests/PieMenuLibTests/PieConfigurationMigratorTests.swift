import XCTest
@testable import PieMenuLib

final class PieConfigurationMigratorTests: XCTestCase {
    func test_migrate_legacyConfigGetsCurrentSchemaVersion() {
        var config = PieConfiguration.defaultConfig
        config.schemaVersion = 0
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.schemaVersion, PieConfiguration.currentSchemaVersion)
    }

    func test_migrate_futureConfigClampedToCurrent() {
        var config = PieConfiguration.defaultConfig
        config.schemaVersion = PieConfiguration.currentSchemaVersion + 5
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.schemaVersion, PieConfiguration.currentSchemaVersion)
    }

    func test_migrate_currentConfigUnchanged() {
        var config = PieConfiguration.defaultConfig
        let original = config.schemaVersion
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.schemaVersion, original)
    }

    func test_migrate_backfillsGlobalSidebarIconColors() {
        let a = PieMenu(name: "One", hotkey: .empty, items: [], globalSidebarIconColorHex: nil)
        let b = PieMenu(name: "Two", hotkey: .empty, items: [], globalSidebarIconColorHex: nil)
        var config = PieConfiguration(menus: [a, b])
        PieConfigurationMigrator.migrate(&config)
        let globals = config.menus.filter { $0.isGlobal && !$0.isRunningAppsMenu }
        XCTAssertEqual(globals.count, 2)
        XCTAssertEqual(globals[0].globalSidebarIconColorHex, PieMenuItem.paletteColor(for: 0))
        XCTAssertEqual(globals[1].globalSidebarIconColorHex, PieMenuItem.paletteColor(for: 1))
    }
}
