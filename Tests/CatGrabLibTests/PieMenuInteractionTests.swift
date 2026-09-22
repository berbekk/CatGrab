import XCTest
@testable import CatGrabLib

final class URLNormalizerTests: XCTestCase {
    func test_bareDomainGetsHTTPS() {
        XCTAssertEqual(URLNormalizer.url(from: "github.com")?.absoluteString, "https://github.com")
        XCTAssertEqual(URLNormalizer.url(from: "  www.apple.com/mac ")?.absoluteString, "https://www.apple.com/mac")
    }

    func test_fullURLsAndOtherSchemesStayAsTheyAre() {
        XCTAssertEqual(URLNormalizer.url(from: "http://example.org/a?b=1")?.absoluteString, "http://example.org/a?b=1")
        XCTAssertEqual(URLNormalizer.url(from: "mailto:cat@example.org")?.scheme, "mailto")
        XCTAssertEqual(URLNormalizer.url(from: "x-apple.systempreferences:com.apple.preference.security")?.scheme, "x-apple.systempreferences")
    }

    func test_hostWithPortIsNotMistakenForAScheme() {
        XCTAssertEqual(URLNormalizer.url(from: "localhost:3000/admin")?.absoluteString, "https://localhost:3000/admin")
        XCTAssertEqual(URLNormalizer.url(from: "127.0.0.1:8080")?.port, 8080)
    }

    func test_spacesArePercentEncodedAndEmptyIsNil() {
        XCTAssertEqual(URLNormalizer.url(from: "example.com/my page")?.absoluteString, "https://example.com/my%20page")
        XCTAssertNil(URLNormalizer.url(from: "   "))
    }

    func test_hostDropsWWW() {
        XCTAssertEqual(URLNormalizer.host(of: "www.github.com/berbekk"), "github.com")
        XCTAssertEqual(URLNormalizer.host(of: "https://docs.swift.org"), "docs.swift.org")
    }
}

final class HoverLabelTests: XCTestCase {
    func test_appAndUnassignedShowOnlyTheTitle() {
        let app = PieMenuItem(title: "Safari", icon: "safari", action: .launchApp(bundleIdentifier: "com.apple.Safari"))
        XCTAssertEqual(app.hoverLabel(language: .english), PieHoverLabelText(title: "Safari", detail: nil))
        let empty = PieMenuItem(title: "", icon: "star.fill", action: .unassigned)
        XCTAssertNil(empty.hoverLabel(language: .english))
    }

    func test_linkShowsItsHostAndKeystrokeItsGlyphs() {
        let link = PieMenuItem(title: "Repo", icon: "link", action: .openURL(url: "www.github.com/berbekk/CatGrab"))
        XCTAssertEqual(link.hoverLabel(language: .english)?.detail, "github.com")
        let keystroke = PieMenuItem(
            title: "New window",
            icon: "keyboard",
            action: .keystroke(keyCode: 45, modifiers: Int(CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue))
        )
        XCTAssertEqual(keystroke.hoverLabel(language: .english)?.detail, "⇧⌘N")
    }

    func test_snippetShowsAShortExcerptOfTheFirstLine() throws {
        let long = String(repeating: "word ", count: 20)
        let snippet = PieMenuItem(title: "Sign-off", icon: "text.quote", action: .snippet(text: "\n\n" + long + "\nsecond line"))
        let detail = try XCTUnwrap(snippet.hoverLabel(language: .english)?.detail)
        XCTAssertTrue(detail.hasSuffix("…"))
        XCTAssertLessThanOrEqual(detail.count, PieHoverLabelText.detailLimit)
        XCTAssertFalse(detail.contains("second"))
    }

    func test_untitledItemUsesTheDetailAsTitle() {
        let link = PieMenuItem(title: "", icon: "link", action: .openURL(url: "example.org"))
        XCTAssertEqual(link.hoverLabel(language: .english), PieHoverLabelText(title: "example.org", detail: nil))
    }

    func test_systemActionFallsBackToItsLocalizedName() {
        let item = PieMenuItem(title: "", icon: "lock", action: .systemShortcut(.missionControl))
        XCTAssertEqual(item.hoverLabel(language: .russian)?.title, "Mission Control")
    }

    func test_hoverLabelSettingRoundTripsAndDefaultsToOn() throws {
        var menu = PieMenu(name: "Main", showsHoverLabel: false)
        let data = try JSONEncoder().encode(menu)
        XCTAssertFalse(try JSONDecoder().decode(PieMenu.self, from: data).showsHoverLabel)

        menu.showsHoverLabel = true
        let json = try XCTUnwrap(String(data: try JSONEncoder().encode(menu), encoding: .utf8))
            .replacingOccurrences(of: "\"showsHoverLabel\":true,", with: "")
            .replacingOccurrences(of: ",\"showsHoverLabel\":true", with: "")
        XCTAssertTrue(try JSONDecoder().decode(PieMenu.self, from: Data(json.utf8)).showsHoverLabel)
    }

    func test_hoverLabelSettingTravelsWithTheTheme() {
        var source = PieMenu(name: "A", showsHoverLabel: false)
        source.menuRadius = 120
        let theme = CustomMenuTheme(name: "Quiet", menu: source)
        var target = PieMenu(name: "B")
        target.applyTheme(theme)
        XCTAssertFalse(target.showsHoverLabel)
        XCTAssertTrue(theme.matches(target))
    }
}

final class PieMenuPlacementTests: XCTestCase {
    func test_centerStaysUnderThePointerAwayFromEdges() {
        let center = PieMenuPlacement.clampedCenter(
            proposed: CGPoint(x: 500, y: 400),
            radius: 150,
            bounds: CGSize(width: 1440, height: 900)
        )
        XCTAssertEqual(center, CGPoint(x: 500, y: 400))
        XCTAssertFalse(PieMenuPlacement.needsCursorWarp(proposed: CGPoint(x: 500, y: 400), center: center))
    }

    func test_ringIsPushedInsideTheScreenAndTheCursorFollows() {
        let proposed = CGPoint(x: 20, y: 880)
        let center = PieMenuPlacement.clampedCenter(proposed: proposed, radius: 150, bounds: CGSize(width: 1440, height: 900))
        XCTAssertEqual(center, CGPoint(x: 150, y: 750))
        XCTAssertTrue(PieMenuPlacement.needsCursorWarp(proposed: proposed, center: center))
    }

    func test_ringLargerThanTheScreenIsCentered() {
        let center = PieMenuPlacement.clampedCenter(proposed: .zero, radius: 600, bounds: CGSize(width: 1000, height: 700))
        XCTAssertEqual(center, CGPoint(x: 500, y: 350))
    }

    func test_arrowsPickTheSectorInTheirDirection() {
        // Four sectors starting at the top, clockwise: 0 up-right, 1 down-right, 2 down-left, 3 up-left.
        // Rotated by -45° their middles sit exactly up, right, down and left.
        let rotation = -Double.pi / 4
        XCTAssertEqual(PieSectorLayout.sectorIndex(closestToDirection: -.pi / 2, sectorCount: 4, rotationRadians: rotation), 0)
        XCTAssertEqual(PieSectorLayout.sectorIndex(closestToDirection: 0, sectorCount: 4, rotationRadians: rotation), 1)
        XCTAssertEqual(PieSectorLayout.sectorIndex(closestToDirection: .pi / 2, sectorCount: 4, rotationRadians: rotation), 2)
        XCTAssertEqual(PieSectorLayout.sectorIndex(closestToDirection: .pi, sectorCount: 4, rotationRadians: rotation), 3)
        XCTAssertNil(PieSectorLayout.sectorIndex(closestToDirection: 0, sectorCount: 0, rotationRadians: 0))
    }

    func test_tabCyclesAroundTheRingFromEitherEnd() {
        XCTAssertEqual(PieSectorLayout.cycledIndex(from: nil, by: 1, sectorCount: 5), 0)
        XCTAssertEqual(PieSectorLayout.cycledIndex(from: nil, by: -1, sectorCount: 5), 4)
        XCTAssertEqual(PieSectorLayout.cycledIndex(from: 4, by: 1, sectorCount: 5), 0)
        XCTAssertEqual(PieSectorLayout.cycledIndex(from: 0, by: -1, sectorCount: 5), 4)
        XCTAssertNil(PieSectorLayout.cycledIndex(from: 0, by: 1, sectorCount: 0))
    }

    func test_highlightStateIgnoresRepeatsAndWrapsWhenAdvancing() {
        let state = PieMenuHighlightState()
        state.select(2, hapticFeedbackEnabled: false)
        state.select(2, hapticFeedbackEnabled: false)
        XCTAssertEqual(state.highlightedIndex, 2)
        state.advanceSelection(sectorCount: 3, hapticFeedbackEnabled: false)
        XCTAssertEqual(state.highlightedIndex, 0)
        state.select(nil, hapticFeedbackEnabled: false)
        XCTAssertNil(state.highlightedIndex)
    }

    @MainActor
    func test_unavailableCommandsAndMissingAppsCannotBeChosen() {
        let missing = PieMenuItem(title: "Ghost", icon: "app", action: .launchApp(bundleIdentifier: "io.example.does.not.exist"))
        let finder = PieMenuItem(title: "Finder", icon: "app", action: .launchApp(bundleIdentifier: "com.apple.finder"))
        let link = PieMenuItem(title: "Site", icon: "link", action: .openURL(url: "example.org"))
        XCTAssertEqual(PieMenuWindowController.disabledIndices(items: [finder, missing, link], commands: nil), [1])

        let enabled = PieSubAction(id: "a", title: "A", icon: "star", shortcut: nil, isDestructive: false, kind: .hideApp, pid: 1)
        let unavailable = PieSubAction(id: "b", title: "B", icon: "star", shortcut: nil, isDestructive: false, kind: .unavailable, pid: 1)
        XCTAssertEqual(PieMenuWindowController.disabledIndices(items: [finder, missing], commands: [enabled, unavailable]), [1])
    }
}

final class MenuDuplicationTests: XCTestCase {
    func test_duplicateGetsNewIdsAndNoTriggers() throws {
        var config = PieConfiguration.defaultConfig
        let original = config.menus[0]
        config.menus[0].trackpadFingerCount = 4

        let copy = try XCTUnwrap(config.duplicateMenu(id: original.id, name: "Main copy"))
        XCTAssertEqual(config.menus[1].id, copy.id)
        XCTAssertEqual(copy.name, "Main copy")
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertTrue(copy.hotkey.isEmpty)
        XCTAssertEqual(copy.trackpadFingerCount, 0)
        XCTAssertEqual(copy.items.map(\.title), original.items.map(\.title))
        XCTAssertTrue(Set(copy.items.map(\.id)).isDisjoint(with: original.items.map(\.id)))
        XCTAssertEqual(copy.colorScheme, original.colorScheme)
    }

    func test_builtInMenusAreNotDuplicated() {
        var config = PieConfiguration.defaultConfig
        let count = config.menus.count
        let dynamic = config.menus.first { $0.isDynamicMenu }
        XCTAssertNil(config.duplicateMenu(id: dynamic?.id ?? UUID(), name: "x"))
        XCTAssertEqual(config.menus.count, count)
    }

    func test_sharedHotkeyIsReportedOnlyForEnabledMenus() {
        var config = PieConfiguration.defaultConfig
        let main = config.menus[0]
        var other = PieMenu(name: "Work", hotkey: main.hotkey)
        config.menus.append(other)
        XCTAssertEqual(config.menuSharingHotkey(with: main)?.name, "Work")
        XCTAssertEqual(config.menuSharingHotkey(with: other)?.name, "Main")

        other.hotkey = .empty
        config.menus[config.menus.count - 1] = other
        XCTAssertNil(config.menuSharingHotkey(with: main))
        XCTAssertNil(config.menuSharingHotkey(with: other))
    }

    func test_nextFreeSectorIndexFillsGaps() {
        var menu = PieConfiguration.defaultConfig.menus[0]
        XCTAssertEqual(menu.nextFreeSectorIndex, menu.items.count)
        menu.items.removeAll { $0.sectorIndex == 2 }
        XCTAssertEqual(menu.nextFreeSectorIndex, 2)
    }
}
