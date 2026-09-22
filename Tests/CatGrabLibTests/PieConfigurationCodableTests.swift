import XCTest
@testable import CatGrabLib

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
        let jsonText = """
        {
            "schemaVersion": 99999,
            "menus": [],
            "language": "en",
            "appMenuHotkey": {"keyCode": -1, "carbonModifiers": 0},
            "hapticFeedbackEnabled": true,
            "lastModified": 0,
            "unknownFutureField": "ignored"
        }
        """
        let json = Data(jsonText.utf8)
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: json)
        // Migrator должен привести schemaVersion к текущей.
        XCTAssertEqual(decoded.schemaVersion, PieConfiguration.currentSchemaVersion)
    }

    func test_menuItem_unknownActionDefaultsToUnassigned() throws {
        let jsonText = """
        {
            "id": "\(UUID().uuidString)",
            "title": "Test",
            "icon": "star",
            "action": {"case": "someFutureActionThatDoesntExist", "payload": {}},
            "color": "#FF0000",
            "sectorIndex": 0
        }
        """
        let json = Data(jsonText.utf8)
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

    func test_menuWithoutIconDistanceKeepsIconsInsideTheRing() throws {
        // A 1.0-era menu: no iconDistance, no innerRadius. The old formula (55 pt from the center)
        // would put icons inside today's wider hub.
        let json = #"{"id":"6E48EB70-6155-429C-B6DF-0CFCBACAD575","name":"Main","hotkey":{"keyCode":49,"carbonModifiers":6144},"items":[],"menuRadius":150,"animationDuration":0.2}"#
        let menu = try JSONDecoder().decode(PieMenu.self, from: Data(json.utf8))
        XCTAssertEqual(menu.iconDistance, 0.5)
        XCTAssertTrue(PieMenu.iconDistanceAllowedRange.contains(menu.iconDistance))

        let stored = json.replacingOccurrences(of: "\"menuRadius\":150", with: "\"menuRadius\":150,\"iconDistance\":0.8")
        XCTAssertEqual(try JSONDecoder().decode(PieMenu.self, from: Data(stored.utf8)).iconDistance, 0.8)
        let broken = json.replacingOccurrences(of: "\"menuRadius\":150", with: "\"menuRadius\":150,\"iconDistance\":-0.3")
        XCTAssertEqual(try JSONDecoder().decode(PieMenu.self, from: Data(broken.utf8)).iconDistance, 0.5)
    }

    func test_legacyPaletteColoursFollowTheThemeEvenAfterReordering() throws {
        // 1.0 stored a colour per sector and kept it when sectors were reordered, so a palette colour
        // can sit at the "wrong" index. It must still follow the theme; a hand-picked colour must not.
        let json = ##"[{"title":"A","icon":"star","color":"#FF9500","sectorIndex":0},{"title":"B","icon":"star","color":"#123456","sectorIndex":1}]"##
        let items = try JSONDecoder().decode([PieMenuItem].self, from: Data(json.utf8))
        XCTAssertTrue(items[0].usesThemeColor)
        XCTAssertFalse(items[1].usesThemeColor)
    }

    func test_defaultGlassIsVisiblyTinted() throws {
        XCTAssertEqual(LiquidGlassSettings.default.tintOpacity, MenuThemePreset.classic.intensity)
        let decoded = try JSONDecoder().decode(LiquidGlassSettings.self, from: Data(#"{"variant":"regular"}"#.utf8))
        XCTAssertEqual(decoded.tintOpacity, LiquidGlassSettings.defaultTintOpacity)
    }
}
