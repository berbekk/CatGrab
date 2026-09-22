import XCTest
@testable import CatGrabLib

/// Меню команд настраивается как обычное меню: свои цвета и клавиша у команды, свой вид у набора приложения.
final class AppCommandSetTests: XCTestCase {
    private let zen = "app.zen-browser.zen"

    private func config(entries: [AppSubMenuEntry] = [AppSubMenuEntry(kind: .tileLeft), AppSubMenuEntry(kind: .quitApp)]) -> PieConfiguration {
        var config = PieConfiguration(menus: [PieMenu(name: "Main")])
        config.ensureDynamicMenusInvariant()
        config.appSubMenus = [AppSubMenu(bundleIdentifier: zen, entries: entries)]
        return config
    }

    private func sharedMenu(_ config: PieConfiguration) -> PieMenu {
        config.menus.first(where: \.isAppCommandsMenu) ?? PieConfiguration.templateAppCommandsMenu()
    }

    func test_commandColorsAndKeyReachTheRing() {
        var entry = AppSubMenuEntry(kind: .tileLeft)
        entry.color = "#123456"
        entry.iconColor = "#FFCC00"
        entry.customShortcut = "K"
        let hide = PieSubAction(id: "a", title: "a", icon: "star", shortcut: nil, isDestructive: false, kind: .hideApp, pid: 1)
        let item = AppCommandsMenuItems.build(actions: [hide], entries: [entry], bundleIdentifier: zen)[0]
        XCTAssertEqual(item.color, "#123456")
        XCTAssertFalse(item.usesThemeColor)
        XCTAssertEqual(item.iconColor, "#FFCC00")
        XCTAssertEqual(item.customShortcut, "K")
        XCTAssertEqual(AppCommandsMenuItems.previewItems(entries: [entry])[0].color, "#123456")
    }

    func test_quitStaysRedInOldSetsButAThemeChoiceSurvivesSaving() throws {
        let legacy = try JSONDecoder().decode(AppSubMenuEntry.self, from: Data(#"{"kind":"quitApp"}"#.utf8))
        XCTAssertEqual(legacy.color, AppSubMenuEntry.destructiveColorHex)

        var themed = legacy
        themed.color = nil
        let decoded = try JSONDecoder().decode(AppSubMenuEntry.self, from: JSONEncoder().encode(themed))
        XCTAssertNil(decoded.color)
    }

    func test_resetReturnsCommandColorsButKeepsQuitRed() {
        var menu = PieConfiguration.templateAppCommandsMenu()
        menu.appCommandsDefaultEntries[0].color = "#123456"
        menu.appCommandsDefaultEntries[1].iconColor = "#FFCC00"
        XCTAssertEqual(menu.customColorCount, 2)
        menu.resetSectorColors()
        XCTAssertEqual(menu.customColorCount, 0)
        XCTAssertEqual(menu.appCommandsDefaultEntries.first { $0.kind == .quitApp }?.color, AppSubMenuEntry.destructiveColorHex)
    }

    func test_oldCommandsMenuKeepsWhiteIcons() throws {
        func decodedWithoutIconStyle(_ menu: PieMenu) throws -> PieMenu {
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(menu)) as? [String: Any])
            json.removeValue(forKey: "iconStyle")
            return try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json))
        }
        XCTAssertEqual(try decodedWithoutIconStyle(PieConfiguration.templateAppCommandsMenu()).iconStyle, .white)
        XCTAssertEqual(try decodedWithoutIconStyle(PieMenu(name: "Main")).iconStyle, .tinted)
    }

    func test_appSetEditsTheSharedLookUntilItHasItsOwn() throws {
        var config = config()
        var menu = try XCTUnwrap(config.appSetMenu(for: zen))
        XCTAssertEqual(menu.appCommandsDefaultEntries.map(\.kind), [.tileLeft, .quitApp])

        menu.applyPalette(try XCTUnwrap(MenuThemePreset.withID("neon")))
        config.updateAppSetMenu(menu, for: zen)
        XCTAssertEqual(sharedMenu(config).colorScheme.presetID, "neon")
        XCTAssertNil(config.appSubMenu(for: zen)?.look)

        config.setAppSetHasOwnLook(true, for: zen)
        menu = try XCTUnwrap(config.appSetMenu(for: zen))
        menu.applyPalette(try XCTUnwrap(MenuThemePreset.withID("forest")))
        config.updateAppSetMenu(menu, for: zen)
        XCTAssertEqual(sharedMenu(config).colorScheme.presetID, "neon", "other apps keep the shared look")
        XCTAssertEqual(config.appCommandsMenu(sharedMenu(config), for: zen).colorScheme.presetID, "forest")
        XCTAssertEqual(config.appCommandsMenu(sharedMenu(config), for: "com.apple.Safari").colorScheme.presetID, "neon")

        config.setAppSetHasOwnLook(false, for: zen)
        XCTAssertEqual(try XCTUnwrap(config.appSetMenu(for: zen)).colorScheme.presetID, "neon")
    }

    func test_appSetCommandsAndRotationStayInTheSet() throws {
        var config = config()
        let sharedBefore = sharedMenu(config)
        var menu = try XCTUnwrap(config.appSetMenu(for: zen))
        menu.appCommandsDefaultEntries.append(AppSubMenuEntry(kind: .hideApp))
        menu.appCommandsDefaultEntries[0].color = "#123456"
        menu.rotationDegrees = 30
        config.updateAppSetMenu(menu, for: zen)

        let set = try XCTUnwrap(config.appSubMenu(for: zen))
        XCTAssertEqual(set.entries.map(\.kind), [.tileLeft, .quitApp, .hideApp])
        XCTAssertEqual(set.entries[0].color, "#123456")
        XCTAssertEqual(set.rotationDegrees, 30)
        XCTAssertEqual(sharedMenu(config), sharedBefore)
    }

    func test_ownLookSurvivesSaving() throws {
        var config = config()
        config.setAppSetHasOwnLook(true, for: zen)
        config.appSubMenus[0].look?.iconStyle = .tinted
        let data = try JSONEncoder().encode(config.appSubMenus[0])
        XCTAssertEqual(try JSONDecoder().decode(AppSubMenu.self, from: data), config.appSubMenus[0])
    }

    // MARK: - Своё действие в меню команд

    func test_customActionSectorSurvivesSaving() throws {
        var entry = AppSubMenuEntry(action: PieMenuItem(title: "Docs", icon: "link", action: .openURL(url: "https://example.com")))
        entry.customShortcut = "D"
        let decoded = try JSONDecoder().decode(AppSubMenuEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(decoded, entry)
        XCTAssertEqual(decoded.displayTitle(appName: "Zen", language: .english), "Docs")
    }

    func test_inspectorEditsKeepACommandUntilAnActionIsChosen() {
        var entry = AppSubMenuEntry(kind: .menuItem, menuPath: ["File", "New Window"])
        var item = entry.asMenuItem(title: "New Window", themeColor: "#0A84FF", sectorIndex: 0)
        XCTAssertEqual(item.action, .unassigned)

        item.icon = "star"
        item.usesThemeColor = false
        item.color = "#123456"
        entry.apply(item)
        XCTAssertEqual(entry.kind, .menuItem)
        XCTAssertEqual(entry.icon, "star")
        XCTAssertEqual(entry.color, "#123456")

        item.action = .openURL(url: "https://example.com")
        entry.apply(item)
        XCTAssertEqual(entry.kind, .action)
        XCTAssertEqual(entry.action, .openURL(url: "https://example.com"))
        XCTAssertTrue(entry.menuPath.isEmpty)
        XCTAssertEqual(entry.color, "#123456", "colours stay when the sector changes what it does")
    }

    func test_choosingACommandReplacesTheActionAndFollowsItsDefaultColour() {
        var entry = AppSubMenuEntry(action: PieMenuItem(title: "Docs", icon: "link", action: .openURL(url: "x")))
        entry.customShortcut = "D"
        entry.replaceCommand(with: AppSubMenuEntry(kind: .quitApp))
        XCTAssertEqual(entry.kind, .quitApp)
        XCTAssertNil(entry.action)
        XCTAssertEqual(entry.color, AppSubMenuEntry.destructiveColorHex)
        XCTAssertEqual(entry.customShortcut, "D")
    }

    func test_customActionRingItemCarriesItsActionForTheAppIcon() {
        let entry = AppSubMenuEntry(action: PieMenuItem(title: "Notes", icon: "app:com.apple.Notes", action: .launchApp(bundleIdentifier: "com.apple.Notes")))
        let run = PieSubAction(id: "a", title: "Notes", icon: "app:com.apple.Notes", shortcut: nil, isDestructive: false,
                               kind: .customAction(PieMenuItem(title: "Notes", icon: "app:com.apple.Notes", action: .launchApp(bundleIdentifier: "com.apple.Notes"))),
                               pid: 1)
        let item = AppCommandsMenuItems.build(actions: [run], entries: [entry], bundleIdentifier: zen)[0]
        XCTAssertEqual(item.action.bundleIdentifier, "com.apple.Notes")
        XCTAssertFalse(entry.hasTintableIcon)
    }

    func test_emptyActionsAreNotRunnable() {
        XCTAssertFalse(MenuAction.unassigned.isConfigured)
        XCTAssertFalse(MenuAction.launchApp(bundleIdentifier: "").isConfigured)
        XCTAssertFalse(MenuAction.openURL(url: "  ").isConfigured)
        XCTAssertFalse(MenuAction.snippet(text: "").isConfigured)
        XCTAssertTrue(MenuAction.openURL(url: "https://example.com").isConfigured)
        XCTAssertTrue(MenuAction.systemShortcut(.missionControl).isConfigured)
    }
}
