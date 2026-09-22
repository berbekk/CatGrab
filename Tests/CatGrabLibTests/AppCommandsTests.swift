import ApplicationServices
import XCTest
@testable import CatGrabLib

final class AppCommandsMenuTests: XCTestCase {
    private func action(_ id: String, destructive: Bool = false) -> PieSubAction {
        PieSubAction(id: id, title: id, icon: "star", shortcut: nil, isDestructive: destructive, kind: .hideApp, pid: 1)
    }

    func test_configAlwaysHasExactlyOneAppCommandsMenu() {
        var config = PieConfiguration(menus: [PieMenu(name: "Main")])
        config.ensureDynamicMenusInvariant()
        XCTAssertEqual(config.menus.filter(\.isAppCommandsMenu).count, 1)
        XCTAssertEqual(config.menus.filter(\.isRunningAppsMenu).count, 1)

        config.menus.append(PieConfiguration.templateAppCommandsMenu())
        config.ensureDynamicMenusInvariant()
        XCTAssertEqual(config.menus.filter(\.isAppCommandsMenu).count, 1)
    }

    func test_newAppCommandsMenuIsDynamicAndWaitsForAHotkey() {
        let menu = PieConfiguration.templateAppCommandsMenu()
        XCTAssertTrue(menu.isDynamicMenu)
        XCTAssertTrue(menu.hotkey.isEmpty)
        XCTAssertTrue(menu.runningAppsMenuEnabled)
        XCTAssertFalse(menu.pawDecorationEnabled)
        XCTAssertEqual(menu.centerAppIconScale, 0.4)
        XCTAssertFalse(PieMenu(name: "Main").isDynamicMenu)
    }

    func test_kindSurvivesARoundTrip() throws {
        let menu = PieConfiguration.templateAppCommandsMenu()
        let decoded = try JSONDecoder().decode(PieMenu.self, from: JSONEncoder().encode(menu))
        XCTAssertEqual(decoded.kind, .appCommands)
    }

    func test_commandsBecomeRingItemsInOrderWithQuitInRed() {
        let menu = PieConfiguration.templateAppCommandsMenu()
        let entries = [AppSubMenuEntry(kind: .toggleFullScreen), AppSubMenuEntry(kind: .hideApp), AppSubMenuEntry(kind: .quitApp)]
        let items = menu.themed(AppCommandsMenuItems.build(
            actions: [action("new"), action("hide"), action("quit", destructive: true)],
            entries: entries,
            bundleIdentifier: "com.apple.Safari"
        ))
        XCTAssertEqual(items.map(\.title), ["new", "hide", "quit"])
        XCTAssertEqual(items.map(\.sectorIndex), [0, 1, 2])
        XCTAssertEqual(items[0].color, menu.colorScheme.color(at: 0, count: 3))
        XCTAssertEqual(items[2].color, AppSubMenuEntry.destructiveColorHex)
        XCTAssertEqual(Set(items.compactMap(\.iconColor)), ["#FFFFFF"], "command icons stay white by default")
    }

    func test_appIconSizeDefaultsForOldConfigsAndStaysOnItsMenu() throws {
        let data = try JSONEncoder().encode(PieConfiguration.templateAppCommandsMenu())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "centerAppIconScale")
        var commands = try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(commands.centerAppIconScale, PieMenu.defaultCenterAppIconScale)

        commands.centerAppIconScale = 0.6
        commands.applySharedVisualSettings(from: PieMenu(name: "Main"))
        XCTAssertEqual(commands.centerAppIconScale, 0.6)
    }

    func test_ringItemIdsAreStableAcrossShows() {
        let first = AppCommandsMenuItems.build(actions: [action("new")], entries: [], bundleIdentifier: "com.apple.Safari")
        let again = AppCommandsMenuItems.build(actions: [action("new")], entries: [], bundleIdentifier: "com.apple.Safari")
        let other = AppCommandsMenuItems.build(actions: [action("new")], entries: [], bundleIdentifier: "com.apple.Terminal")
        XCTAssertEqual(first[0].id, again[0].id)
        XCTAssertNotEqual(first[0].id, other[0].id)
    }

    func test_eachMenuOpensByItsOwnGesture() {
        var commands = PieConfiguration.templateAppCommandsMenu()
        commands.trackpadFingerCount = 3
        var main = PieMenu(name: "Main")
        main.trackpadFingerCount = 4
        let config = PieConfiguration(menus: [main, commands])
        XCTAssertEqual(config.trackpadGestureTargets(), [4: 0, 3: 1])
    }

    func test_disabledAppCommandsMenuIgnoresItsGesture() {
        var commands = PieConfiguration.templateAppCommandsMenu()
        commands.trackpadFingerCount = 3
        commands.runningAppsMenuEnabled = false
        let config = PieConfiguration(menus: [PieMenu(name: "Main"), commands])
        XCTAssertEqual(config.trackpadGestureTargets(), [:])
    }

    func test_menuWithoutOwnGestureDecodesAsOff() throws {
        let data = try JSONEncoder().encode(PieMenu(name: "Main"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "trackpadFingerCount")
        let decoded = try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.trackpadFingerCount, 0)
    }

    func test_oldAppBoundMenusAreDroppedOnLoad() throws {
        let config = PieConfiguration(menus: [
            PieMenu(name: "Main"), PieMenu(name: "Zen"), PieConfiguration.templateRunningAppsMenu()
        ])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var menus = try XCTUnwrap(json["menus"] as? [[String: Any]])
        menus[1]["boundAppBundleId"] = "app.zen-browser.zen"
        // У динамических меню привязка и раньше игнорировалась — такое меню остаётся.
        menus[2]["boundAppBundleId"] = "com.apple.Safari"
        json["menus"] = menus

        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.menus.map(\.name), ["Main", "Active apps"])
    }
}

final class AutomaticCommandSetTests: XCTestCase {
    /// Середина сектора в градусах по часовой стрелке от верха кольца, с поворотом меню по умолчанию.
    private func sectorCenter(of kind: AppSubMenuEntry.Kind) throws -> Double {
        let kinds = AppSubMenuEntry.automaticBuiltIns.map(\.kind)
        let index = try XCTUnwrap(kinds.firstIndex(of: kind))
        let step = 360.0 / Double(kinds.count)
        let center = PieConfiguration.templateAppCommandsMenu().rotationDegrees + step * (Double(index) + 0.5)
        return (center + 360).truncatingRemainder(dividingBy: 360)
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    func test_automaticSetIsWindowPlacementFullScreenAndQuit() {
        XCTAssertEqual(
            Set(AppSubMenuEntry.automaticBuiltIns.map(\.kind)),
            [.toggleFullScreen, .quitApp, .tileLeft, .tileRight, .tileTop, .tileBottom, .fillScreen, .centerWindow]
        )
    }

    func test_eachHalfSitsExactlyOnItsSideOfTheRing() throws {
        XCTAssertEqual(angularDistance(try sectorCenter(of: .tileTop), 0), 0, accuracy: 0.001)
        XCTAssertEqual(try sectorCenter(of: .tileRight), 90, accuracy: 0.001)
        XCTAssertEqual(try sectorCenter(of: .tileBottom), 180, accuracy: 0.001)
        XCTAssertEqual(try sectorCenter(of: .tileLeft), 270, accuracy: 0.001)
    }

    func test_previousSixCommandDefaultIsUpgradedOnce() {
        var commands = PieConfiguration.templateAppCommandsMenu()
        let previous: [AppSubMenuEntry.Kind] = [.toggleFullScreen, .tileRight, .tileBottom, .tileLeft, .quitApp, .tileTop]
        commands.appCommandsDefaultEntries = previous.map { AppSubMenuEntry(kind: $0) }
        commands.rotationDegrees = 30
        var config = PieConfiguration(menus: [PieMenu(name: "Main"), commands], schemaVersion: 2)
        PieConfigurationMigrator.migrate(&config)
        let upgraded = config.menus[1]
        XCTAssertEqual(upgraded.appCommandsDefaultEntries.map(\.kind), AppSubMenuEntry.automaticBuiltIns.map(\.kind))
        XCTAssertEqual(upgraded.rotationDegrees, AppSubMenuEntry.automaticRingRotationDegrees)

        // Уже на новой схеме набор не трогаем, даже если в нём снова шесть команд.
        config.menus[1].appCommandsDefaultEntries = previous.map { AppSubMenuEntry(kind: $0) }
        PieConfigurationMigrator.migrate(&config)
        XCTAssertEqual(config.menus[1].appCommandsDefaultEntries.map(\.kind), previous)
    }

    func test_copiedCommandGetsItsOwnID() {
        let entry = AppSubMenuEntry(kind: .menuItem, menuPath: ["File", "New Tab"], shortcut: MenuShortcut("T"), icon: "star")
        let copy = entry.withNewID
        XCTAssertNotEqual(copy.id, entry.id)
        XCTAssertEqual(copy.kind, entry.kind)
        XCTAssertEqual(copy.menuPath, entry.menuPath)
        XCTAssertEqual(copy.shortcut, entry.shortcut)
        XCTAssertEqual(copy.icon, entry.icon)
    }

    func test_onlyTheCommandsMenuHasADefaultSet() throws {
        XCTAssertEqual(
            PieConfiguration.templateAppCommandsMenu().appCommandsDefaultEntries.map(\.kind),
            AppSubMenuEntry.automaticBuiltIns.map(\.kind)
        )
        XCTAssertTrue(PieMenu(name: "Main").appCommandsDefaultEntries.isEmpty)

        // Меню из конфига, где набора по умолчанию ещё не было, получает стандартный.
        let data = try JSONEncoder().encode(PieConfiguration.templateAppCommandsMenu())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "appCommandsDefaultEntries")
        let decoded = try JSONDecoder().decode(PieMenu.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.appCommandsDefaultEntries.map(\.kind), AppSubMenuEntry.automaticBuiltIns.map(\.kind))
    }

    func test_reorderedDefaultSetIsSavedAndUsedForAppsWithoutTheirOwn() throws {
        var commands = PieConfiguration.templateAppCommandsMenu()
        commands.appCommandsDefaultEntries.swapAt(0, 3)
        let config = PieConfiguration(menus: [PieMenu(name: "Main"), commands])
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.defaultAppCommands, commands.appCommandsDefaultEntries)
        XCTAssertEqual(decoded.defaultAppCommands.first?.kind, AppSubMenuEntry.automaticBuiltIns[3].kind)
    }
}

final class WindowTilingTests: XCTestCase {
    /// Рабочая область 1440×875 под строкой меню в 25 pt (координаты Accessibility).
    private let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)

    func test_halvesSplitTheWorkAreaWithoutGaps() {
        let left = WindowAX.tileFrame(.left, in: screen)
        let right = WindowAX.tileFrame(.right, in: screen)
        XCTAssertEqual(left, CGRect(x: 0, y: 25, width: 720, height: 875))
        XCTAssertEqual(right, CGRect(x: 720, y: 25, width: 720, height: 875))
        XCTAssertEqual(WindowAX.tileFrame(.fill, in: screen), screen)
    }

    func test_topAndBottomHalvesSplitTheHeight() {
        XCTAssertEqual(WindowAX.tileFrame(.top, in: screen), CGRect(x: 0, y: 25, width: 1440, height: 437))
        XCTAssertEqual(WindowAX.tileFrame(.bottom, in: screen), CGRect(x: 0, y: 462, width: 1440, height: 438))
        XCTAssertEqual(WindowAX.tileFrame(.bottom, in: screen).maxY, screen.maxY)
    }

    func test_centeringKeepsTheWindowSize() {
        let window = CGRect(x: 10, y: 40, width: 800, height: 500)
        XCTAssertEqual(WindowAX.centeredFrame(window, in: screen), CGRect(x: 320, y: 213, width: 800, height: 500))
        // Окно больше рабочей области ужимается до неё.
        let huge = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        XCTAssertEqual(WindowAX.centeredFrame(huge, in: screen), screen)
    }

    func test_oddWidthGivesTheExtraPointToTheRightHalf() {
        let odd = CGRect(x: 0, y: 0, width: 1001, height: 600)
        XCTAssertEqual(WindowAX.tileFrame(.left, in: odd).width, 500)
        XCTAssertEqual(WindowAX.tileFrame(.right, in: odd).width, 501)
        XCTAssertEqual(WindowAX.tileFrame(.right, in: odd).maxX, odd.maxX)
    }

    func test_windowTilesOnTheScreenItIsOn() {
        let external = CGRect(x: 1440, y: 0, width: 1920, height: 1055)
        let screens = [screen, external]
        XCTAssertEqual(WindowAX.screenFrame(containing: CGPoint(x: 2000, y: 400), in: screens), external)
        // Середина окна за краем всех экранов — берём ближайший.
        XCTAssertEqual(WindowAX.screenFrame(containing: CGPoint(x: -50, y: 300), in: screens), screen)
    }

    func test_appKitFramesConvertToAccessibilityCoordinates() {
        // Главный экран 900 pt высотой; рабочая область без строки меню сверху и Dock снизу.
        let visible = CGRect(x: 0, y: 70, width: 1440, height: 805)
        XCTAssertEqual(
            WindowAX.accessibilityFrame(visible, primaryScreenHeight: 900),
            CGRect(x: 0, y: 25, width: 1440, height: 805)
        )
    }
}
