import XCTest
@testable import CatGrabLib

final class MenuThemeTests: XCTestCase {
    private func item(_ color: String, at index: Int, themed: Bool = true) -> PieMenuItem {
        PieMenuItem(title: "\(index)", icon: "star", action: .unassigned, color: color, usesThemeColor: themed, sectorIndex: index)
    }

    // MARK: Scheme

    func test_paletteCyclesGradientSpansAndSingleRepeats() {
        let palette = SectorColorScheme(mode: .palette, colors: ["#FF0000", "#00FF00", "#0000FF"], presetID: nil)
        XCTAssertEqual((0..<5).map { palette.color(at: $0, count: 5) }, ["#FF0000", "#00FF00", "#0000FF", "#FF0000", "#00FF00"])

        let gradient = SectorColorScheme(mode: .gradient, colors: ["#000000", "#FFFFFF"], presetID: nil)
        XCTAssertEqual(gradient.color(at: 0, count: 5), "#000000")
        XCTAssertEqual(gradient.color(at: 2, count: 5), "#808080")
        XCTAssertEqual(gradient.color(at: 4, count: 5), "#FFFFFF")

        let single = SectorColorScheme(mode: .single, colors: ["#123456"], presetID: nil)
        XCTAssertEqual(single.color(at: 7, count: 9), "#123456")
    }

    func test_switchingModeKeepsTheCharacterAndMakesItCustom() {
        var scheme = MenuThemePreset.classic.scheme
        scheme.switchMode(to: .gradient)
        XCTAssertEqual(scheme.colors, [PieMenuItem.sectorPalette.first, PieMenuItem.sectorPalette.last].compactMap { $0 })
        XCTAssertNil(scheme.presetID)

        scheme.switchMode(to: .single)
        XCTAssertEqual(scheme.colors.count, 1)
        scheme.switchMode(to: .palette)
        XCTAssertEqual(scheme.colors.count, 6)
        XCTAssertEqual(scheme.colors.first, PieMenuItem.sectorPalette.first)
    }

    // MARK: Menu

    func test_themedColorsFollowPositionAndKeepOwnColors() {
        var menu = PieMenu(name: "Main", items: [item("#AAAAAA", at: 0), item("#123456", at: 1, themed: false), item("#AAAAAA", at: 2)])
        menu.colorScheme = SectorColorScheme(mode: .palette, colors: ["#FF0000", "#00FF00", "#0000FF"], presetID: nil)
        XCTAssertEqual(menu.themed(menu.items).map(\.color), ["#FF0000", "#123456", "#0000FF"])

        menu.iconStyle = .white
        XCTAssertEqual(menu.themed(menu.items).map(\.iconColor), ["#FFFFFF", "#FFFFFF", "#FFFFFF"])
        XCTAssertEqual(menu.items.map(\.iconColor), [nil, nil, nil])
    }

    func test_applyingAPaletteSetsItsColoursAndKeepsOwnColors() throws {
        let ocean = try XCTUnwrap(MenuThemePreset.withID("ocean"))
        var menu = PieMenu(name: "Main", items: [item("#AAAAAA", at: 0), item("#123456", at: 1, themed: false)])
        menu.applyPalette(ocean)
        XCTAssertEqual(menu.colorScheme, ocean.scheme)
        XCTAssertEqual(menu.liquidGlass.tintOpacity, ocean.intensity)
        XCTAssertEqual(menu.liquidGlass.variant, ocean.glass)
        XCTAssertEqual(menu.iconStyle, ocean.icons)
        XCTAssertEqual(menu.customColorCount, 1)

        menu.resetSectorColors()
        XCTAssertEqual(menu.customColorCount, 0)
    }

    func test_sharedStyleCarriesTheColorSchemeButNotItemColors() throws {
        var template = PieMenu(name: "Main")
        template.applyPalette(try XCTUnwrap(MenuThemePreset.withID("neon")))
        var other = PieMenu(name: "Work", items: [item("#123456", at: 0, themed: false)])
        other.applySharedVisualSettings(from: template)
        XCTAssertEqual(other.colorScheme, template.colorScheme)
        XCTAssertEqual(other.iconStyle, template.iconStyle)
        XCTAssertFalse(other.items[0].usesThemeColor)
    }

    // MARK: Old configs

    func test_oldItemsWithTheirDefaultColorFollowTheThemeOthersKeepTheirs() throws {
        func decode(color: String, sectorIndex: Int) throws -> PieMenuItem {
            let json: [String: Any] = ["title": "x", "icon": "star", "color": color, "sectorIndex": sectorIndex]
            return try JSONDecoder().decode(PieMenuItem.self, from: JSONSerialization.data(withJSONObject: json))
        }
        XCTAssertTrue(try decode(color: PieMenuItem.paletteColor(for: 2).lowercased(), sectorIndex: 2).usesThemeColor)
        // 1.0 kept a sector's palette colour when the sector was moved: still a theme colour.
        XCTAssertTrue(try decode(color: PieMenuItem.paletteColor(for: 3), sectorIndex: 2).usesThemeColor)
        XCTAssertFalse(try decode(color: "#123456", sectorIndex: 0).usesThemeColor)
    }

    func test_iconColorWrittenByTheOldPickerFollowsTheThemeAgain() throws {
        func decode(color: String, iconColor: String) throws -> PieMenuItem {
            let json: [String: Any] = ["title": "x", "icon": "text:me", "color": color, "iconColor": iconColor, "sectorIndex": 6]
            return try JSONDecoder().decode(PieMenuItem.self, from: JSONSerialization.data(withJSONObject: json))
        }
        XCTAssertNil(try decode(color: "#AF52DE", iconColor: "#B053DF").iconColor)
        XCTAssertEqual(try decode(color: "#AF52DE", iconColor: "#FFCC00").iconColor, "#FFCC00")
    }

    func test_whiteIconsAndResetCoverIconsWithOwnColors() {
        var menu = PieMenu(name: "Main", items: [
            PieMenuItem(title: "a", icon: "star", action: .unassigned, iconColor: "#FF0000", sectorIndex: 0),
            PieMenuItem(title: "b", icon: "app:com.apple.Safari", action: .unassigned, iconColor: "#FF0000", sectorIndex: 1)
        ])
        XCTAssertEqual(menu.customColorCount, 1, "an app icon is drawn in its own colors, so it does not count")
        menu.resetSectorColors()
        menu.iconStyle = .white
        XCTAssertEqual(menu.themed(menu.items).map(\.iconColor), ["#FFFFFF", "#FFFFFF"])
        XCTAssertEqual(menu.customColorCount, 0)
    }

    func test_oldMenusGetClassicAndTheIntermediateAccentBecomesOneColor() throws {
        let data = try JSONEncoder().encode(PieMenu(name: "Main"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "colorScheme")
        json.removeValue(forKey: "iconStyle")
        let decode = { try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json)) }
        XCTAssertEqual(try decode().colorScheme, MenuThemePreset.classic.scheme)
        XCTAssertEqual(try decode().iconStyle, .tinted)

        json["accent"] = "green"
        XCTAssertEqual(try decode().colorScheme, SectorColorScheme(mode: .single, colors: ["#30D158"], presetID: nil))

        json["colorScheme"] = ["mode": "spiral", "colors": ["#FFFFFF"]]
        json.removeValue(forKey: "accent")
        XCTAssertEqual(try decode().colorScheme, MenuThemePreset.classic.scheme)
    }

    func test_quitStaysRedWhateverTheTheme() throws {
        var menu = PieConfiguration.templateAppCommandsMenu()
        menu.applyPalette(try XCTUnwrap(MenuThemePreset.withID("mint")))
        let items = menu.themed(AppCommandsMenuItems.previewItems(entries: [AppSubMenuEntry(kind: .tileLeft), AppSubMenuEntry(kind: .quitApp)]))
        XCTAssertEqual(items[1].color, DS.Pie.destructiveSubSectorTintHex)
        XCTAssertNotEqual(items[0].color, DS.Pie.destructiveSubSectorTintHex)
    }

    // MARK: Catalogues

    func test_presetsAreUniqueAndValid() {
        let presets = MenuThemePreset.all
        XCTAssertEqual(presets.count, 24)
        XCTAssertEqual(presets.count % 4, 0, "the gallery is a 4-column grid")
        XCTAssertEqual(Set(presets.map(\.id)).count, presets.count)
        for preset in presets {
            XCTAssertFalse(preset.scheme.colors.isEmpty, preset.id)
            XCTAssertTrue(preset.scheme.colors.allSatisfy(HexColor.isValid), preset.id)
            XCTAssertEqual(preset.scheme.presetID, preset.id)
            XCTAssertTrue((0...0.7).contains(preset.intensity), preset.id)
        }
    }

    func test_swatchLibraryIsAFullGridOfDistinctColors() {
        let all = ColorSwatchLibrary.all
        XCTAssertEqual(all.count, ColorSwatchLibrary.columns * 7)
        XCTAssertEqual(Set(all).count, all.count)
        XCTAssertTrue(all.allSatisfy(HexColor.isValid))
    }

    func test_appearanceDefaultsToSystemAndRoundTrips() throws {
        var config = PieConfiguration.defaultConfig
        XCTAssertEqual(config.appearance, .system)
        config.appearance = .dark
        let data = try JSONEncoder().encode(config)
        XCTAssertEqual(try JSONDecoder().decode(PieConfiguration.self, from: data).appearance, .dark)
    }

    // MARK: - Свои темы

    func test_customThemeIsTheWholeStyleAndAppliesToAnotherMenu() throws {
        var source = PieMenu(name: "Main")
        source.applyPalette(try XCTUnwrap(MenuThemePreset.withID("sunset")))
        source.colorScheme.colors[0] = "#123456"
        source.liquidGlass.tintOpacity = 0.42
        source.menuRadius = 170
        source.innerRadius = 70
        source.pawDecorationEnabled = false
        source.shortcutDigitOpacity = 0.3
        source.catColorHex = "#FF9500"
        source.pawColorHex = "#34C759"
        let theme = CustomMenuTheme(name: "Моя", menu: source)

        var target = PieMenu(name: "Work")
        target.rotationDegrees = 15
        target.applyTheme(theme)
        XCTAssertEqual(target.colorScheme.colors, source.colorScheme.colors)
        XCTAssertEqual(target.liquidGlass.tintOpacity, 0.42)
        XCTAssertEqual(target.menuRadius, 170)
        XCTAssertEqual(target.innerRadius, 70)
        XCTAssertFalse(target.pawDecorationEnabled)
        XCTAssertEqual(target.shortcutDigitOpacity, 0.3)
        XCTAssertEqual(target.catColorHex, "#FF9500")
        XCTAssertEqual(target.pawColorHex, "#34C759")
        XCTAssertEqual(target.rotationDegrees, 15, "rotation depends on the sector count and stays the menu's own")
        XCTAssertTrue(theme.matches(target))

        target.menuRadius = 150
        XCTAssertFalse(theme.matches(target), "a changed shape no longer matches the theme")
    }

    func test_themeKeepsTheCommandMenusAppIconSize() {
        let theme = CustomMenuTheme(name: "Моя", menu: PieMenu(name: "Main"))
        var commands = PieConfiguration.templateAppCommandsMenu()
        commands.centerAppIconScale = 0.6
        commands.applyTheme(theme)
        XCTAssertEqual(commands.centerAppIconScale, 0.6)
        XCTAssertTrue(theme.matches(commands))
    }

    func test_themeSavedBeforeCatAndPawColorsStillLoadsWithDefaults() throws {
        var menu = PieMenu(name: "Main")
        var theme = CustomMenuTheme(name: "Old", menu: menu)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(theme)) as? [String: Any])
        var look = try XCTUnwrap(json["look"] as? [String: Any])
        look.removeValue(forKey: "catColorHex")
        look.removeValue(forKey: "pawColorHex")
        json["look"] = look
        let decoded = try JSONDecoder().decode(CustomMenuTheme.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.look.catColorHex, PieMenu.defaultCatColorHex)
        XCTAssertEqual(decoded.look.pawColorHex, PieMenu.defaultPawColorHex)

        menu.catColorHex = "#FF2D55"
        theme.update(from: menu)
        XCTAssertEqual(theme.look.catColorHex, "#FF2D55")
    }

    func test_colourOnlyThemesFromTheFirstVersionStillLoad() throws {
        let id = UUID()
        let json = """
        {"id":"\(id.uuidString)","name":"Old","scheme":{"mode":"single","colors":["#FF0000"]},
         "intensity":0.5,"glass":"clear","icons":"white"}
        """
        let theme = try JSONDecoder().decode(CustomMenuTheme.self, from: Data(json.utf8))
        XCTAssertEqual(theme.look.colorScheme.colors, ["#FF0000"])
        XCTAssertEqual(theme.look.liquidGlass.tintOpacity, 0.5)
        XCTAssertEqual(theme.look.liquidGlass.variant, .clear)
        XCTAssertEqual(theme.look.menuRadius, PieMenu(name: "x").menuRadius)
        XCTAssertNil(theme.look.themeID)
    }

    func test_customThemesSurviveSavingAndOldConfigsHaveNone() throws {
        var config = PieConfiguration(menus: [PieMenu(name: "Main")])
        config.customThemes = [CustomMenuTheme(name: "Моя", menu: config.menus[0])]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: data)
        XCTAssertEqual(decoded.customThemes, config.customThemes)

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "customThemes")
        let old = try JSONDecoder().decode(PieConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(old.customThemes.isEmpty)
    }

    func test_unreadableCustomThemeIsSkipped() throws {
        var config = PieConfiguration(menus: [PieMenu(name: "Main")])
        config.customThemes = [CustomMenuTheme(name: "Моя", menu: config.menus[0])]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var themes = try XCTUnwrap(json["customThemes"] as? [[String: Any]])
        themes.append(["name": "broken"])
        json["customThemes"] = themes
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.customThemes.map(\.name), ["Моя"])
    }

    func test_updatingACustomThemeKeepsItsNameAndIdentity() {
        var menu = PieMenu(name: "Main")
        var theme = CustomMenuTheme(name: "Моя", menu: menu)
        menu.iconStyle = menu.iconStyle == .white ? .tinted : .white
        theme.update(from: menu)
        XCTAssertEqual(theme.name, "Моя")
        XCTAssertEqual(theme.look.iconStyle, menu.iconStyle)
        XCTAssertNil(theme.look.themeID)
    }

    /// Перетаскивание меняет номера секторов, а не порядок пунктов: меню и превью должны раскрасить
    /// каждый сектор одинаково.
    func test_themeColoursFollowRingPlaceNotArrayOrder() throws {
        var menu = PieMenu(name: "Main")
        menu.applyPalette(try XCTUnwrap(MenuThemePreset.withID("ocean")))
        menu.items = (0..<6).map { PieMenuItem(title: "\($0)", icon: "star", action: .unassigned, sectorIndex: $0) }
        menu.items[1].sectorIndex = 4
        menu.items[4].sectorIndex = 1

        let window = menu.themed(menu.items).sorted { $0.sectorIndex < $1.sectorIndex }
        let preview = menu.themed(menu.items.sorted { $0.sectorIndex < $1.sectorIndex })
        XCTAssertEqual(window.map(\.color), preview.map(\.color))
        XCTAssertEqual(window.map(\.color), (0..<6).map { menu.colorScheme.color(at: $0, count: 6) })
    }

    /// В меню с многими секторами иконка уменьшается и помещается в сектор; в обычном — как задано.
    func test_iconsShrinkToFitNarrowSectors() {
        let menu = PieMenu(name: "Main")
        XCTAssertEqual(menu.fittedIconSize(sectorCount: 8), menu.effectiveIconSize)
        let crowded = menu.fittedIconSize(sectorCount: 14)
        XCTAssertLessThan(crowded, menu.effectiveIconSize)
        XCTAssertLessThan(menu.fittedIconSize(sectorCount: 20), crowded)
        XCTAssertGreaterThanOrEqual(menu.fittedIconSize(sectorCount: 200), 12)
    }

    // MARK: - Меню привязаны к теме

    private func themedConfig() -> (PieConfiguration, CustomMenuTheme) {
        var config = PieConfiguration(menus: [PieMenu(name: "Main"), PieMenu(name: "Work"), PieMenu(name: "Solo")])
        config.ensureDynamicMenusInvariant()
        let theme = config.createTheme(named: "Рабочая", from: config.menus[0])
        config.menus[0].applyTheme(theme)
        config.menus[1].applyTheme(theme)
        return (config, theme)
    }

    func test_editingAThemedMenuIsAnUnsavedThemeChangeUntilRevertedOrSaved() throws {
        var (config, theme) = themedConfig()
        XCTAssertFalse(config.menus[0].hasUnsavedThemeChanges(in: config.customThemes))

        config.menus[0].applyPalette(try XCTUnwrap(MenuThemePreset.withID("neon")))
        XCTAssertEqual(config.menus[0].themeID, theme.id, "a palette changes the theme's colours, not the link")
        XCTAssertTrue(config.menus[0].hasUnsavedThemeChanges(in: config.customThemes))

        config.menus[0].applyTheme(theme)
        XCTAssertFalse(config.menus[0].hasUnsavedThemeChanges(in: config.customThemes), "revert")
    }

    func test_savingAThemeUpdatesEveryMenuOfThatThemeOnly() throws {
        var (config, theme) = themedConfig()
        let soloBefore = config.menus[2]
        config.menus[0].menuRadius = 170
        config.menus[0].applyPalette(try XCTUnwrap(MenuThemePreset.withID("forest")))
        config.saveTheme(theme.id, from: config.menus[0])

        XCTAssertEqual(config.menus[1].menuRadius, 170)
        XCTAssertEqual(config.menus[1].colorScheme.presetID, "forest")
        XCTAssertFalse(config.menus[1].hasUnsavedThemeChanges(in: config.customThemes))
        XCTAssertEqual(config.menus[2], soloBefore, "a menu without the theme is left alone")
    }

    func test_savingAThemeReachesAppSetsWithTheirOwnLook() throws {
        var (config, theme) = themedConfig()
        let commands = try XCTUnwrap(config.menus.firstIndex(where: \.isAppCommandsMenu))
        config.menus[commands].applyTheme(theme)
        config.appSubMenus = [AppSubMenu(bundleIdentifier: "com.apple.Safari", entries: AppSubMenuEntry.automaticBuiltIns)]
        config.setAppSetHasOwnLook(true, for: "com.apple.Safari")
        XCTAssertEqual(config.appSubMenus[0].look?.themeID, theme.id)

        config.menus[0].iconStyle = config.menus[0].iconStyle == .white ? .tinted : .white
        config.saveTheme(theme.id, from: config.menus[0])
        XCTAssertEqual(config.appSubMenus[0].look?.iconStyle, config.menus[0].iconStyle)
        XCTAssertEqual(config.menus[commands].iconStyle, config.menus[0].iconStyle)
    }

    func test_deletingAThemeUnlinksItsMenusButKeepsTheirLook() {
        var (config, theme) = themedConfig()
        let look = MenuLook(config.menus[1])
        config.deleteTheme(theme.id)
        XCTAssertTrue(config.customThemes.isEmpty)
        XCTAssertNil(config.menus[1].themeID)
        var expected = look
        expected.themeID = nil
        XCTAssertEqual(MenuLook(config.menus[1]), expected)
    }

    func test_menusThemedByTheFirstVersionBecomeLinked() throws {
        let id = UUID()
        var menu = PieMenu(name: "Main")
        menu.colorScheme.presetID = CustomMenuTheme.legacyIDPrefix + id.uuidString
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(menu)) as? [String: Any])
        json.removeValue(forKey: "themeID")
        let decoded = try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.themeID, id)
        XCTAssertNil(decoded.colorScheme.presetID)
    }
}
