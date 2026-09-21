import XCTest
@testable import CatGrabLib

final class RunningAppFocusTests: XCTestCase {
    private func window(
        number: CGWindowID,
        pid: pid_t,
        layer: Int = 0,
        alpha: Double = 1,
        size: CGSize = CGSize(width: 800, height: 600)
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: number,
            kCGWindowOwnerPID as String: pid,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: alpha,
            kCGWindowBounds as String: CGRect(origin: .zero, size: size).dictionaryRepresentation
        ]
    }

    func test_picksFirstNormalWindowOfTheProcess() {
        let list = [
            window(number: 1, pid: 99),
            window(number: 2, pid: 42),
            window(number: 3, pid: 42)
        ]
        XCTAssertEqual(RunningAppFocus.frontmostWindowID(in: list, ownerPID: 42), 2)
    }

    func test_skipsMenuBarLayerInvisibleAndTinyWindows() {
        let list = [
            window(number: 1, pid: 42, layer: 25),
            window(number: 2, pid: 42, alpha: 0),
            window(number: 3, pid: 42, size: CGSize(width: 10, height: 10)),
            window(number: 4, pid: 42)
        ]
        XCTAssertEqual(RunningAppFocus.frontmostWindowID(in: list, ownerPID: 42), 4)
    }

    func test_noWindowsMeansNoFocusTarget() {
        let list = [window(number: 1, pid: 99)]
        XCTAssertNil(RunningAppFocus.frontmostWindowID(in: list, ownerPID: 42))
    }
}
