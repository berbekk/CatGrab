import XCTest
@testable import CatGrabLib

final class HotkeyInputStateTests: XCTestCase {
    func test_releaseStillBelongsToTheHotkeyAfterModifiersChange() {
        var state = HotkeyInputState()
        XCTAssertEqual(state.key(keyCode: 48, isDown: true, isRepeat: false, matching: [2]), .pressed([2]))
        XCTAssertEqual(state.key(keyCode: 48, isDown: false, isRepeat: false, matching: nil), .released([2]))
        XCTAssertEqual(state.key(keyCode: 48, isDown: false, isRepeat: false, matching: [2]), .passThrough)
    }

    func test_autoRepeatDoesNotToggleTheMenuButANewPressDoes() {
        var state = HotkeyInputState()
        _ = state.key(keyCode: 48, isDown: true, isRepeat: false, matching: [0])
        XCTAssertEqual(state.key(keyCode: 48, isDown: true, isRepeat: true, matching: [0]), .consume)
        _ = state.key(keyCode: 48, isDown: false, isRepeat: false, matching: [0])
        XCTAssertEqual(state.key(keyCode: 48, isDown: true, isRepeat: false, matching: [0]), .pressed([0]))
    }

    func test_startingWhileAKeyIsHeldDoesNotCaptureItsRepeatOrRelease() {
        var state = HotkeyInputState()
        XCTAssertEqual(state.key(keyCode: 48, isDown: true, isRepeat: true, matching: [0]), .passThrough)
        XCTAssertEqual(state.key(keyCode: 48, isDown: false, isRepeat: false, matching: [0]), .passThrough)
    }

    func test_fnWithOtherModifiersAndArrowFlagsDoNotOpenStandaloneFnMenu() {
        var state = HotkeyInputState()
        XCTAssertEqual(state.fn(keyCode: 63, isDown: true, hasOtherModifiers: true, indices: [0]), .passThrough)
        XCTAssertEqual(state.fn(keyCode: 63, isDown: false, hasOtherModifiers: true, indices: [0]), .passThrough)
        XCTAssertEqual(state.fn(keyCode: 126, isDown: true, hasOtherModifiers: false, indices: [0]), .passThrough)
        XCTAssertEqual(state.fn(keyCode: 63, isDown: true, hasOtherModifiers: false, indices: [0]), .pressed([0]))
        XCTAssertEqual(state.fn(keyCode: 55, isDown: true, hasOtherModifiers: true, indices: [0]), .passThrough)
        XCTAssertEqual(state.fn(keyCode: 63, isDown: false, hasOtherModifiers: true, indices: [0]), .released([0]))
    }

    func test_appearanceChangesDoNotRequireReregisteringHotkeys() {
        var config = PieConfiguration.defaultConfig
        let original = HotkeyRegistration.bindings(for: config.menus)
        config.menus[0].name = "Renamed"
        config.menus[0].rotationDegrees = 42
        config.menus[0].trackpadFingerCount = 4
        XCTAssertEqual(HotkeyRegistration.bindings(for: config.menus), original)
        config.menus[0].hotkey = .empty
        XCTAssertNotEqual(HotkeyRegistration.bindings(for: config.menus), original)
    }

    func test_reorderingMenusAndDisablingADynamicMenuRequireRegistration() {
        var menus = PieConfiguration.defaultConfig.menus
        let original = HotkeyRegistration.bindings(for: menus)
        menus.swapAt(0, 1)
        XCTAssertNotEqual(HotkeyRegistration.bindings(for: menus), original)
        menus.swapAt(0, 1)
        if let index = menus.firstIndex(where: \.isRunningAppsMenu) {
            menus[index].runningAppsMenuEnabled = false
        }
        XCTAssertNotEqual(HotkeyRegistration.bindings(for: menus), original)
    }

    func test_invalidImportedKeyValuesAreDisabledWithoutIntegerConversionTraps() {
        for keyCode in [Int.min, -1, 128, Int.max] {
            XCTAssertTrue(HotkeyConfig(keyCode: keyCode, carbonModifiers: 0).isEmpty)
        }
        XCTAssertTrue(HotkeyConfig(keyCode: 48, carbonModifiers: -1).isEmpty)
        XCTAssertTrue(HotkeyConfig(keyCode: 48, carbonModifiers: Int.max).isEmpty)
        XCTAssertEqual(HotkeyConfig.keystrokeDisplayString(keyCode: -1, modifiers: -1, language: .english), "Unassigned")
    }

    func test_newDefaultDoesNotTakeACharacterAndSavedShortcutsStayUnchanged() throws {
        XCTAssertEqual(HotkeyConfig.defaultHotkey.keyCode, 49)
        XCTAssertEqual(HotkeyConfig.defaultHotkey.carbonModifiers, CarbonModifiers.control | CarbonModifiers.option | CarbonModifiers.command)
        let saved = HotkeyConfig(keyCode: 18, carbonModifiers: CarbonModifiers.shift)
        XCTAssertEqual(try JSONDecoder().decode(HotkeyConfig.self, from: JSONEncoder().encode(saved)), saved)
    }

    @MainActor
    func test_overlappingRecordersOnlyResumeHotkeysAfterTheLastOneStops() async {
        let session = HotkeyCaptureSession()
        let first = session.begin()
        let second = session.begin()
        session.end(first)
        XCTAssertTrue(session.isRecording)
        session.end(first)
        XCTAssertTrue(session.isRecording)
        session.end(second)
        XCTAssertFalse(session.isRecording)
    }
}
