import XCTest
@testable import CatGrabLib

final class HotkeyConfigTests: XCTestCase {
    func test_carbonModifiersFromNSEventFlags_roundTrip() {
        let flags: NSEvent.ModifierFlags = [.command, .shift, .option]
        let carbon = CarbonModifiers.carbon(from: flags)
        XCTAssertEqual(carbon & CarbonModifiers.command, CarbonModifiers.command)
        XCTAssertEqual(carbon & CarbonModifiers.shift, CarbonModifiers.shift)
        XCTAssertEqual(carbon & CarbonModifiers.option, CarbonModifiers.option)
        XCTAssertEqual(carbon & CarbonModifiers.control, 0)
    }

    func test_carbonModifiersFromCGEventFlags_roundTrip() {
        let flags: CGEventFlags = [.maskCommand, .maskControl]
        let carbon = CarbonModifiers.carbon(from: flags)
        XCTAssertEqual(carbon & CarbonModifiers.command, CarbonModifiers.command)
        XCTAssertEqual(carbon & CarbonModifiers.control, CarbonModifiers.control)
        XCTAssertEqual(carbon & CarbonModifiers.shift, 0)
    }

    func test_hotkeyEmpty_isEmpty() {
        XCTAssertTrue(HotkeyConfig.empty.isEmpty)
        XCTAssertFalse(HotkeyConfig(keyCode: KeyCodes.tab, carbonModifiers: CarbonModifiers.command).isEmpty)
    }

    func test_normalizedKeystroke_fnArrowKeysRemapped() {
        // Fn+стрелка пришла как PageUp (116), с fnGlobeHeld=true → должна нормализоваться в Arrow Up (126).
        let result = HotkeyConfig.normalizedKeystrokeFromRecording(
            keyCode: 116,
            carbonModifiers: 0,
            fnGlobeHeld: true
        )
        XCTAssertEqual(result.keyCode, 126)
        XCTAssertNotEqual(result.cgModifiers & Int(CGEventFlags.maskSecondaryFn.rawValue), 0)
    }

    func test_normalizedKeystroke_plainKeyNotRemapped() {
        let result = HotkeyConfig.normalizedKeystrokeFromRecording(
            keyCode: KeyCodes.tab,
            carbonModifiers: CarbonModifiers.command,
            fnGlobeHeld: false
        )
        XCTAssertEqual(result.keyCode, KeyCodes.tab)
        XCTAssertNotEqual(result.cgModifiers & Int(CGEventFlags.maskCommand.rawValue), 0)
        XCTAssertEqual(result.cgModifiers & Int(CGEventFlags.maskSecondaryFn.rawValue), 0)
    }
}
