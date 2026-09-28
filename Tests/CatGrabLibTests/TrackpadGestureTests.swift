import XCTest
@testable import CatGrabLib

final class TrackpadGestureTests: XCTestCase {
    private func fingers(_ count: Int, offset: Float = 0) -> [TrackpadTapRecognizer.Touch] {
        (0..<count).map { TrackpadTapRecognizer.Touch(id: Int32($0), x: 0.2 + Float($0) * 0.1 + offset, y: 0.5) }
    }

    func test_fourFingerTap_recognized() {
        var r = TrackpadTapRecognizer(fingerCount: 4)
        XCTAssertFalse(r.process(touches: fingers(2), timestamp: 0))
        XCTAssertFalse(r.process(touches: fingers(4), timestamp: 0.03))
        XCTAssertFalse(r.process(touches: fingers(4), timestamp: 0.1))
        XCTAssertFalse(r.process(touches: fingers(1), timestamp: 0.15))
        XCTAssertTrue(r.process(touches: [], timestamp: 0.18))
    }

    func test_swipe_notRecognized() {
        var r = TrackpadTapRecognizer(fingerCount: 4)
        _ = r.process(touches: fingers(4), timestamp: 0)
        _ = r.process(touches: fingers(4, offset: 0.2), timestamp: 0.1)
        XCTAssertFalse(r.process(touches: [], timestamp: 0.15))
    }

    func test_longHold_notRecognized() {
        var r = TrackpadTapRecognizer(fingerCount: 4)
        _ = r.process(touches: fingers(4), timestamp: 0)
        XCTAssertFalse(r.process(touches: [], timestamp: 1.0))
    }

    func test_moreFingersThanConfigured_notRecognized() {
        var r = TrackpadTapRecognizer(fingerCount: 4)
        _ = r.process(touches: fingers(4), timestamp: 0)
        _ = r.process(touches: fingers(5), timestamp: 0.02)
        _ = r.process(touches: fingers(5), timestamp: 0.08)
        _ = r.process(touches: fingers(5), timestamp: 0.12)
        XCTAssertFalse(r.process(touches: [], timestamp: 0.14))
    }

    /// Frames every 10 ms: three fingers down for 120 ms, a fourth brushes the pad for `graze` seconds.
    private func threeFingerTapWithGraze(_ graze: Double, recognizer: inout TrackpadTapRecognizer) -> Bool {
        var t = 0.0
        while t <= 0.12 + 1e-9 {
            let grazing = t >= 0.04 && t < 0.04 + graze
            _ = recognizer.process(touches: fingers(grazing ? 4 : 3), timestamp: t)
            t += 0.01
        }
        return recognizer.process(touches: [], timestamp: 0.13)
    }

    func test_briefFourthContactDuringAThreeFingerTapIsIgnored() {
        var three = TrackpadTapRecognizer(fingerCount: 3)
        var four = TrackpadTapRecognizer(fingerCount: 4)
        XCTAssertTrue(threeFingerTapWithGraze(0.03, recognizer: &three))
        XCTAssertFalse(threeFingerTapWithGraze(0.03, recognizer: &four))
    }

    func test_fourthFingerHeldForMostOfTheTapCountsAsFour() {
        var three = TrackpadTapRecognizer(fingerCount: 3)
        var four = TrackpadTapRecognizer(fingerCount: 4)
        XCTAssertFalse(threeFingerTapWithGraze(0.07, recognizer: &three))
        XCTAssertTrue(threeFingerTapWithGraze(0.07, recognizer: &four))
    }

    func test_grazingContactThatSlidesDoesNotCancelTheTap() {
        var r = TrackpadTapRecognizer(fingerCount: 3)
        var t = 0.0
        while t <= 0.12 + 1e-9 {
            var touches = fingers(3)
            if t >= 0.05 && t < 0.07 {
                touches.append(.init(id: 9, x: 0.9 - Float(t), y: 0.1 + Float(t) * 3))
            }
            _ = r.process(touches: touches, timestamp: t)
            t += 0.01
        }
        XCTAssertTrue(r.process(touches: [], timestamp: 0.13))
    }

    func test_recognizerResetsBetweenTouches() {
        var r = TrackpadTapRecognizer(fingerCount: 3)
        _ = r.process(touches: fingers(4), timestamp: 0)
        XCTAssertFalse(r.process(touches: [], timestamp: 0.1))
        _ = r.process(touches: fingers(3), timestamp: 5)
        XCTAssertTrue(r.process(touches: [], timestamp: 5.1))
    }

    func test_assigningAFingerCountTakesItFromOtherMenus() throws {
        var config = PieConfiguration.defaultConfig
        let main = config.menus[0].id
        let running = try XCTUnwrap(config.menus.first(where: \.isRunningAppsMenu)).id
        config.assignTrackpadFingerCount(4, toMenuId: main)
        config.assignTrackpadFingerCount(3, toMenuId: running)
        XCTAssertEqual(config.trackpadGestureTargets().mapValues { config.menus[$0].id }, [4: main, 3: running])

        config.assignTrackpadFingerCount(4, toMenuId: running)
        XCTAssertEqual(config.menus[0].trackpadFingerCount, 0)
        XCTAssertEqual(config.trackpadGestureTargets().mapValues { config.menus[$0].id }, [4: running])

        config.assignTrackpadFingerCount(0, toMenuId: running)
        XCTAssertEqual(config.trackpadGestureTargets(), [:])
    }

    func test_configuration_roundTripsMenuGestureAndDefaultsToOff() throws {
        var config = PieConfiguration.defaultConfig
        XCTAssertEqual(config.trackpadGestureTargets(), [:])
        config.assignTrackpadFingerCount(4, toMenuId: config.menus[0].id)
        let data = try JSONEncoder().encode(config)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["trackpadGesture"])
        let decoded = try JSONDecoder().decode(PieConfiguration.self, from: data)
        XCTAssertEqual(decoded.menus[0].trackpadFingerCount, 4)
    }

    // MARK: - Общий жест из старых конфигов

    private func decodeWithLegacyGesture(
        _ config: PieConfiguration,
        fingerCount: Int,
        menuId: UUID?
    ) throws -> PieConfiguration {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(config)) as? [String: Any])
        var gesture: [String: Any] = ["fingerCount": fingerCount]
        if let menuId { gesture["menuId"] = menuId.uuidString }
        json["trackpadGesture"] = gesture
        return try JSONDecoder().decode(PieConfiguration.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func test_legacyGestureMovesIntoTheMenuItOpened() throws {
        let config = PieConfiguration.defaultConfig
        let running = try XCTUnwrap(config.menus.first(where: \.isRunningAppsMenu))
        let decoded = try decodeWithLegacyGesture(config, fingerCount: 4, menuId: running.id)
        XCTAssertEqual(decoded.menus.first(where: \.isRunningAppsMenu)?.trackpadFingerCount, 4)
        XCTAssertEqual(decoded.menus[0].trackpadFingerCount, 0)
    }

    func test_legacyGestureWithUnknownMenuFallsBackToFirstStandardMenu() throws {
        let config = PieConfiguration(menus: [PieConfiguration.templateAppCommandsMenu(), PieMenu(name: "Main")])
        let decoded = try decodeWithLegacyGesture(config, fingerCount: 4, menuId: UUID())
        XCTAssertEqual(decoded.menus.map(\.trackpadFingerCount), [0, 4])
        let withoutMenu = try decodeWithLegacyGesture(config, fingerCount: 4, menuId: nil)
        XCTAssertEqual(withoutMenu.menus.map(\.trackpadFingerCount), [0, 4])
    }

    func test_legacyGestureNeverMovesIntoTheAppCommandsMenu() throws {
        let commands = PieConfiguration.templateAppCommandsMenu()
        let config = PieConfiguration(menus: [PieMenu(name: "Main"), commands])
        let decoded = try decodeWithLegacyGesture(config, fingerCount: 3, menuId: commands.id)
        XCTAssertEqual(decoded.menus.map(\.trackpadFingerCount), [3, 0])
    }

    /// Своё касание меню и раньше побеждало общий жест с тем же числом пальцев.
    func test_legacyGestureYieldsToAMenuThatAlreadyHasTheSameCount() throws {
        var commands = PieConfiguration.templateAppCommandsMenu()
        commands.trackpadFingerCount = 4
        let main = PieMenu(name: "Main")
        let decoded = try decodeWithLegacyGesture(
            PieConfiguration(menus: [main, commands]), fingerCount: 4, menuId: main.id
        )
        XCTAssertEqual(decoded.menus.map(\.trackpadFingerCount), [0, 4])
    }

    func test_disabledLegacyGestureChangesNothing() throws {
        let config = PieConfiguration.defaultConfig
        let decoded = try decodeWithLegacyGesture(config, fingerCount: 0, menuId: config.menus[0].id)
        XCTAssertEqual(decoded.trackpadGestureTargets(), [:])
    }
}
