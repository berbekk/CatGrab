import XCTest
@testable import CatGrabLib

final class FirstLaunchConfigurationTests: XCTestCase {
    func test_preferredLanguage_takesFirstSupportedSystemLanguage() {
        XCTAssertEqual(AppLanguage.preferred(from: ["ru-RU", "en-US"]), .russian)
        XCTAssertEqual(AppLanguage.preferred(from: ["zh-Hans-CN"]), .chinese)
        XCTAssertEqual(AppLanguage.preferred(from: ["pt_BR"]), .portuguese)
        XCTAssertEqual(AppLanguage.preferred(from: ["uk-UA", "de-DE"]), .german)
    }

    func test_preferredLanguage_fallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.preferred(from: []), .english)
        XCTAssertEqual(AppLanguage.preferred(from: ["uk-UA", "ko-KR"]), .english)
    }

    func test_firstLaunchConfig_usesSystemLanguageAndLocalizedNames() {
        let names = ["com.apple.Notes": "Заметки", "com.apple.Music": "Музыка"]
        let config = PieConfiguration.firstLaunchConfig(preferredLanguages: ["ru-RU"]) { names[$0] }
        XCTAssertEqual(config.language, .russian)
        XCTAssertEqual(config.menus[0].name, "Главное меню")
        let titles = config.menus[0].items.map(\.title)
        XCTAssertTrue(titles.contains("Заметки"))
        XCTAssertTrue(titles.contains("Музыка"))
        XCTAssertTrue(titles.contains("Safari"), "an app that is not installed keeps its default title")
    }

    func test_firstLaunchConfig_keepsStructureOfDefaultConfig() {
        let config = PieConfiguration.firstLaunchConfig(preferredLanguages: ["en-US"]) { _ in nil }
        var expected = PieConfiguration.defaultConfig
        expected.lastModified = config.lastModified
        for index in expected.menus.indices { expected.menus[index].id = config.menus[index].id }
        XCTAssertEqual(config.menus.map(\.kind), expected.menus.map(\.kind))
        XCTAssertEqual(config.menus[0].hotkey, expected.menus[0].hotkey)
        XCTAssertEqual(config.menus[0].items.map(\.action), expected.menus[0].items.map(\.action))
        XCTAssertEqual(config.menus[0].name, "Main")
    }

    func test_keycapParts_matchTheKeyboard() {
        XCTAssertEqual(HotkeyConfig.defaultHotkey.keycapParts, ["⌃", "⌥", "⌘", "Space"])
        XCTAssertEqual(HotkeyConfig(keyCode: 48, carbonModifiers: 256).keycapParts, ["⌘", "⇥"])
        XCTAssertEqual(HotkeyConfig.empty.keycapParts, [])
    }
}
