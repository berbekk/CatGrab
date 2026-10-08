import XCTest
@testable import CatGrabLib

final class SystemLookUpGestureTests: XCTestCase {
    func test_tapLookUpIsOnWhenAnyTrackpadHasIt() {
        XCTAssertTrue(SystemLookUpGesture.isEnabled(values: [2, 2]))
        XCTAssertTrue(SystemLookUpGesture.isEnabled(values: [0, 2]))
        XCTAssertTrue(SystemLookUpGesture.isEnabled(values: [nil, 2]))
    }

    func test_missingOrZeroMeansForceClickLookUp() {
        XCTAssertFalse(SystemLookUpGesture.isEnabled(values: [0, 0]))
        XCTAssertFalse(SystemLookUpGesture.isEnabled(values: [nil, nil]))
        XCTAssertFalse(SystemLookUpGesture.isEnabled(values: []))
    }
}
