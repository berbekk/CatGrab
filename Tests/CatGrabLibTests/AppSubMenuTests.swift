import XCTest
@testable import CatGrabLib

final class AppSubMenuCodableTests: XCTestCase {
    func test_roundTripKeepsOrderIconsAndShortcuts() throws {
        let subMenu = AppSubMenu(bundleIdentifier: "com.apple.Safari", entries: [
            AppSubMenuEntry(kind: .hideApp),
            AppSubMenuEntry(kind: .menuItem, menuPath: ["File", "New Private Window"], shortcut: MenuShortcut("N", .shift)),
            AppSubMenuEntry(kind: .quitApp, icon: "🚪")
        ])
        let config = PieConfiguration(menus: [], appSubMenus: [subMenu])

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: data)

        XCTAssertEqual(decoded.appSubMenus, [subMenu])
        let entry = decoded.appSubMenus[0].entries[1]
        XCTAssertEqual(entry.shortcut, MenuShortcut("N", .shift))
        XCTAssertEqual(entry.menuTitle, "New Private Window")
    }

    func test_olderConfigWithoutSubMenusDecodesToEmpty() throws {
        let json = #"{"menus": [], "language": "en"}"#
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.appSubMenus, [])
    }

    func test_unknownOrBrokenEntriesAreSkippedNotFatal() throws {
        let json = #"""
        {"bundleIdentifier": "com.example.App", "entries": [
            {"kind": "hideApp"},
            {"kind": "teleportWindow"},
            {"kind": "menuItem", "menuPath": ["File"]},
            {"kind": "menuItem", "menuPath": ["File", "New"]}
        ]}
        """#
        let decoded = try JSONDecoder().decode(AppSubMenu.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.entries.map(\.kind), [.hideApp, .menuItem])
        XCTAssertEqual(decoded.entries.last?.menuPath, ["File", "New"])
    }

    func test_lookupIgnoresBundleIdCase() {
        let config = PieConfiguration(menus: [], appSubMenus: [AppSubMenu(bundleIdentifier: "com.Apple.Safari")])
        XCTAssertNotNil(config.appSubMenu(for: "com.apple.safari"))
        XCTAssertNil(config.appSubMenu(for: "com.apple.Terminal"))
    }
}

final class AppCommandAvailabilityTests: XCTestCase {
    private func action(_ id: String) -> PieSubAction {
        PieSubAction(id: id, title: id, icon: "star", shortcut: nil, isDestructive: false, kind: .hideApp, pid: 1)
    }

    func test_unavailableCommandStaysInPlaceButIsDisabled() {
        let placeholder = PieSubAction(
            id: "unavailable:0", title: "New Tab", icon: "plus", shortcut: nil,
            isDestructive: false, kind: .unavailable, pid: 1
        )
        XCTAssertFalse(placeholder.isEnabled)
        XCTAssertTrue(action("hide").isEnabled)
    }
}

final class SubActionIconGuessTests: XCTestCase {
    func test_shortcutHelpsWhenTitleSaysNothing() {
        XCTAssertEqual(SubActionIconGuess.icon(title: "Whatever", shortcut: MenuShortcut("N")), "macwindow.badge.plus")
    }

    func test_titleBeatsAmbiguousShortcut() {
        // ⇧⌘N — «частное окно» в браузере, но «новая папка» в Finder.
        XCTAssertEqual(SubActionIconGuess.icon(title: "Новое частное окно", shortcut: MenuShortcut("N", .shift)), "sunglasses")
        XCTAssertEqual(SubActionIconGuess.icon(title: "Новая папка", shortcut: MenuShortcut("N", .shift)), "folder.badge.plus")
        XCTAssertEqual(
            SubActionIconGuess.icon(title: "Открыть последнюю закрытую вкладку", shortcut: MenuShortcut("T", .shift)),
            "arrow.uturn.backward"
        )
        XCTAssertEqual(SubActionIconGuess.icon(title: "Закрыть окно", shortcut: MenuShortcut("W")), "xmark.square")
        XCTAssertEqual(SubActionIconGuess.icon(title: "Close Tab", shortcut: nil), "xmark.square")
    }

    func test_titleWordsPickAnIconInEnglishAndRussian() {
        XCTAssertEqual(SubActionIconGuess.icon(title: "New Private Window", shortcut: nil), "sunglasses")
        XCTAssertEqual(SubActionIconGuess.icon(title: "Открыть новую вкладку", shortcut: nil), "plus.square.on.square")
        XCTAssertEqual(SubActionIconGuess.icon(title: "Export as PDF…", shortcut: nil), "square.and.arrow.up")
    }

    func test_matchesWordStartsOnly() {
        // «tab» в середине слова «Stable» не считается.
        XCTAssertEqual(SubActionIconGuess.icon(title: "Stable Build", shortcut: nil), "command")
    }

    func test_ownIconOverridesTheGuess() {
        let entry = AppSubMenuEntry(kind: .menuItem, menuPath: ["File", "New Window"], icon: "🦊")
        XCTAssertEqual(entry.resolvedIcon, "🦊")
        XCTAssertEqual(AppSubMenuEntry(kind: .quitApp).resolvedIcon, "power")
    }
}

final class MenuActionFocusTests: XCTestCase {
    func test_onlyActionsAimedAtThePreviousAppRestoreItsFocus() {
        XCTAssertTrue(MenuAction.keystroke(keyCode: 0, modifiers: 256).needsPreviousAppFocus)
        XCTAssertTrue(MenuAction.snippet(text: "hi").needsPreviousAppFocus)
        XCTAssertFalse(MenuAction.launchApp(bundleIdentifier: "com.apple.Safari").needsPreviousAppFocus)
        XCTAssertFalse(MenuAction.openURL(url: "https://example.com").needsPreviousAppFocus)
    }

    func test_setRotationRoundTripsAndOldSetsHaveNone() throws {
        let set = AppSubMenu(bundleIdentifier: "com.apple.Safari", entries: [AppSubMenuEntry(kind: .quitApp)], rotationDegrees: 30)
        let decoded = try JSONDecoder().decode(AppSubMenu.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(decoded.rotationDegrees, 30)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(set)) as? [String: Any])
        json.removeValue(forKey: "rotationDegrees")
        let legacy = try JSONDecoder().decode(AppSubMenu.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.rotationDegrees)
    }

    func test_appCommandsMenuUsesTheSetRotationOnlyInItsApp() {
        let commands = PieConfiguration.templateAppCommandsMenu()
        let config = PieConfiguration(
            menus: [PieMenu(name: "Main"), commands],
            appSubMenus: [
                AppSubMenu(bundleIdentifier: "com.apple.Safari", rotationDegrees: 45),
                AppSubMenu(bundleIdentifier: "com.apple.finder")
            ]
        )
        XCTAssertEqual(config.appCommandsMenu(commands, for: "com.apple.safari").rotationDegrees, 45)
        XCTAssertEqual(config.appCommandsMenu(commands, for: "com.apple.finder").rotationDegrees, commands.rotationDegrees)
        XCTAssertEqual(config.appCommandsMenu(commands, for: "com.apple.Terminal").rotationDegrees, commands.rotationDegrees)
    }
}
