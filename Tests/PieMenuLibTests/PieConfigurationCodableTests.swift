import XCTest
@testable import PieMenuLib

final class PieConfigurationCodableTests: XCTestCase {
    func test_defaultConfig_roundTrip() throws {
        let original = PieConfiguration.defaultConfig
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, PieConfiguration.currentSchemaVersion)
        XCTAssertEqual(decoded.menus.count, original.menus.count)
        XCTAssertEqual(decoded.language, original.language)
    }

    func test_decode_unknownFieldsTolerated() throws {
        let json = """
        {
            "schemaVersion": 99999,
            "menus": [],
            "language": "en",
            "appMenuHotkey": {"keyCode": -1, "carbonModifiers": 0},
            "hapticFeedbackEnabled": true,
            "lastModified": 0,
            "unknownFutureField": "ignored"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: json)
        // Migrator должен привести schemaVersion к текущей.
        XCTAssertEqual(decoded.schemaVersion, PieConfiguration.currentSchemaVersion)
    }

    func test_menuItem_unknownActionDefaultsToUnassigned() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Test",
            "icon": "star",
            "action": {"case": "someFutureActionThatDoesntExist", "payload": {}},
            "color": "#FF0000",
            "sectorIndex": 0
        }
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(PieMenuItem.self, from: json)
        if case .unassigned = item.action {
            // OK — неизвестное действие безопасно деградировало.
        } else {
            XCTFail("Expected .unassigned for unknown action, got \(item.action)")
        }
    }

    func test_hotkey_roundTrip() throws {
        let original = HotkeyConfig(
            keyCode: KeyCodes.tab,
            carbonModifiers: CarbonModifiers.command | CarbonModifiers.shift
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyConfig.self, from: data)
        XCTAssertEqual(decoded.keyCode, original.keyCode)
        XCTAssertEqual(decoded.carbonModifiers, original.carbonModifiers)
    }
}
