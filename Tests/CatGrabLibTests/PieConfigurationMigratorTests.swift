import XCTest
@testable import CatGrabLib

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
        let globals = config.menus.filter { !$0.isDynamicMenu }
        XCTAssertEqual(globals.count, 2)
        XCTAssertEqual(globals[0].globalSidebarIconColorHex, PieMenuItem.paletteColor(for: 0))
        XCTAssertEqual(globals[1].globalSidebarIconColorHex, PieMenuItem.paletteColor(for: 1))
    }

    func test_migrateV3_centersTheRunningAppsRingOnce() {
        var config = PieConfiguration.defaultConfig
        config.schemaVersion = 3
        guard let index = config.menus.firstIndex(where: \.isRunningAppsMenu) else { return XCTFail("no running apps menu") }
        config.menus[index].rotationDegrees = -12.857
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.menus[index].rotationDegrees, 0)
        XCTAssertEqual(config.schemaVersion, PieConfiguration.currentSchemaVersion)

        config.menus[index].rotationDegrees = 30
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.menus[index].rotationDegrees, 30, "a rotation chosen after the migration stays")
    }

    func test_runningAppsRingPutsTheFirstSectorStraightUpForAnyCount() {
        let menu = PieConfiguration.templateRunningAppsMenu()
        for count in [3, 6, 7, 12] {
            let start = PieSectorLayout.sectorAngles(
                index: 0,
                sectorCount: count,
                rotationRadians: menu.effectiveRotationDegrees(sectorCount: count) * .pi / 180,
                innerRadius: 0,
                outerRadius: 1
            )
            XCTAssertEqual((start.start + start.end) / 2, -.pi / 2, accuracy: 1e-9, "count \(count)")
        }
        let standard = PieConfiguration.defaultConfig.menus[0]
        XCTAssertEqual(standard.effectiveRotationDegrees(sectorCount: 6), standard.rotationDegrees)
    }
}
