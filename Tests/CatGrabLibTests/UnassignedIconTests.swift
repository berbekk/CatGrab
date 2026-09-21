import XCTest
@testable import CatGrabLib

final class UnassignedIconTests: XCTestCase {
    func test_randomSymbol_comesFromPool() {
        for _ in 0..<200 {
            XCTAssertTrue(PieMenuItem.unassignedSymbolPool.contains(PieMenuItem.randomUnassignedSymbol()))
        }
    }

    func test_randomSymbol_neverTheLegacyCat() {
        XCTAssertFalse(PieMenuItem.unassignedSymbolPool.contains(PieMenuItem.legacyUnassignedSFSymbol))
    }

    func test_randomSymbol_avoidsUsedIcons() {
        let pool = PieMenuItem.unassignedSymbolPool
        // Свободным оставляем ровно один символ — выбор обязан попасть в него.
        let onlyFree = pool[pool.count / 2]
        let used = Set(pool).subtracting([onlyFree])
        for _ in 0..<50 {
            XCTAssertEqual(PieMenuItem.randomUnassignedSymbol(avoiding: used), onlyFree)
        }
    }

    func test_randomSymbol_fallsBackToPoolWhenEverythingUsed() {
        let used = Set(PieMenuItem.unassignedSymbolPool)
        XCTAssertTrue(used.contains(PieMenuItem.randomUnassignedSymbol(avoiding: used)))
    }

    func test_migrateV1_replacesLegacyCatOnUnassignedItemsOnly() throws {
        let cat = PieMenuItem.legacyUnassignedSFSymbol
        let items = [
            PieMenuItem(title: "a", icon: cat, action: .unassigned, sectorIndex: 0),
            PieMenuItem(title: "b", icon: cat, action: .unassigned, sectorIndex: 1),
            // Кот, выбранный для настоящего действия, — осознанный выбор, его не трогаем.
            PieMenuItem(title: "c", icon: cat, action: .launchApp(bundleIdentifier: "com.apple.Notes"), sectorIndex: 2),
            // Пустой пункт с другой иконкой тоже не трогаем.
            PieMenuItem(title: "d", icon: "star.fill", action: .unassigned, sectorIndex: 3)
        ]
        var config = PieConfiguration(menus: [PieMenu(name: "M", hotkey: .empty, items: items)], schemaVersion: 1)

        PieConfigurationMigrator.migrate(&config)

        let migrated = try XCTUnwrap(config.menus.first?.items)
        XCTAssertNotEqual(migrated[0].icon, cat)
        XCTAssertNotEqual(migrated[1].icon, cat)
        XCTAssertTrue(PieMenuItem.unassignedSymbolPool.contains(migrated[0].icon))
        XCTAssertNotEqual(migrated[0].icon, migrated[1].icon, "соседние пустые пункты не должны совпадать")
        XCTAssertFalse([migrated[0].icon, migrated[1].icon].contains("star.fill"), "занятая в меню иконка не повторяется")
        XCTAssertEqual(migrated[2].icon, cat)
        XCTAssertEqual(migrated[3].icon, "star.fill")
        XCTAssertEqual(config.schemaVersion, PieConfiguration.currentSchemaVersion)
    }

    func test_migrate_currentVersionKeepsManuallyChosenCat() throws {
        let item = PieMenuItem(title: "a", icon: PieMenuItem.legacyUnassignedSFSymbol, action: .unassigned)
        var config = PieConfiguration(menus: [PieMenu(name: "M", hotkey: .empty, items: [item])])

        PieConfigurationMigrator.migrate(&config)

        XCTAssertEqual(try XCTUnwrap(config.menus.first?.items.first).icon, PieMenuItem.legacyUnassignedSFSymbol)
    }
}
