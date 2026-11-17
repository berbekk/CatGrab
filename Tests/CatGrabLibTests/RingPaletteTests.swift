import XCTest
@testable import CatGrabLib

final class RingPaletteTests: XCTestCase {
    private let light = RingPalette(isDark: false, isSolid: false)
    private let dark = RingPalette(isDark: true, isSolid: false)

    func test_contrastRatio_matchesWCAGExtremes() {
        XCTAssertEqual(HexColor.contrastRatio("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        XCTAssertEqual(HexColor.contrastRatio("#777777", "#777777"), 1, accuracy: 0.0001)
    }

    func test_readable_keepsColorThatAlreadyReads() {
        let sector = dark.sectorHex(tint: "#007AFF", alpha: 0.3)
        XCTAssertEqual(dark.readable("#FFFFFF", on: sector), "#FFFFFF")
    }

    func test_whiteIconsTurnDarkOnLightRing() {
        let sector = light.sectorHex(tint: "#34C759", alpha: 0.3)
        XCTAssertEqual(light.readable("#FFFFFF", on: sector), RingPalette.darkInkHex)
    }

    func test_darkDigitsTurnWhiteOnDarkRing() {
        let sector = dark.sectorHex(tint: "#1A1A6E", alpha: 0.55)
        XCTAssertEqual(dark.readable("#000000", on: sector), RingPalette.lightInkHex)
    }

    /// Цветной значок сохраняет оттенок — темнеет, пока не станет читаться.
    func test_tintedIconKeepsHueAndReachesContrast() throws {
        let sector = light.sectorHex(tint: "#FFCC00", alpha: 0.45)
        let fixed = light.readable("#FFCC00", on: sector)
        XCTAssertNotEqual(fixed, "#FFCC00")
        XCTAssertGreaterThanOrEqual(HexColor.contrastRatio(fixed, sector), RingPalette.minimumContrast)
        let original = try XCTUnwrap(HexColor.toHSB("#FFCC00"))
        let result = try XCTUnwrap(HexColor.toHSB(fixed))
        XCTAssertEqual(result.h, original.h, accuracy: 0.02)
    }

    func test_darkTintedIconLightensOnDarkRing() {
        let sector = dark.sectorHex(tint: "#03045E", alpha: 0.5)
        let fixed = dark.readable("#03045E", on: sector)
        XCTAssertGreaterThanOrEqual(HexColor.contrastRatio(fixed, sector), RingPalette.minimumContrast)
        XCTAssertGreaterThan(HexColor.relativeLuminance(fixed), HexColor.relativeLuminance("#03045E"))
    }

    func test_systemAppearanceFollowsMacOS() {
        let settings = LiquidGlassSettings(appearance: .system)
        XCTAssertTrue(RingPalette(settings: settings, systemIsDark: true).isDark)
        XCTAssertFalse(RingPalette(settings: settings, systemIsDark: false).isDark)
        XCTAssertTrue(RingPalette(settings: LiquidGlassSettings(appearance: .dark), systemIsDark: false).isDark)
    }

    func test_settingsSavedBeforeAppearance_stayDark() throws {
        let json = Data(#"{"variant":"clear","tintOpacity":0.4}"#.utf8)
        let settings = try JSONDecoder().decode(LiquidGlassSettings.self, from: json)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.variant, .clear)
    }

    func test_unknownVariantFallsBackToRegular() throws {
        let json = Data(#"{"variant":"holographic","tintOpacity":0.4,"appearance":"light"}"#.utf8)
        let settings = try JSONDecoder().decode(LiquidGlassSettings.self, from: json)
        XCTAssertEqual(settings.variant, .regular)
        XCTAssertEqual(settings.appearance, .light)
    }

    func test_settingsRoundTrip() throws {
        let original = LiquidGlassSettings(variant: .solid, tintOpacity: 0.2, appearance: .system)
        let decoded = try JSONDecoder().decode(LiquidGlassSettings.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
    }

    /// Палитра меняет цвета, но не отменяет «Без стекла» и не трогает светлое кольцо.
    func test_applyingPaletteKeepsSolidAndAppearance() throws {
        var menu = PieMenu(name: "Test")
        menu.liquidGlass.variant = .solid
        menu.liquidGlass.appearance = .light
        let preset = try XCTUnwrap(MenuThemePreset.withID("crystal"))
        menu.applyPalette(preset)
        XCTAssertEqual(menu.liquidGlass.variant, .solid)
        XCTAssertEqual(menu.liquidGlass.appearance, .light)
        XCTAssertEqual(menu.colorScheme, preset.scheme)
    }
}
