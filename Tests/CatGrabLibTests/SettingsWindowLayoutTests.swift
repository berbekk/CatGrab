import XCTest
@testable import CatGrabLib

final class SettingsWindowLayoutTests: XCTestCase {
    private let minimum = CGSize(width: 880, height: 520)

    func test_windowFitsSmallAndScaledMacBookDisplays() {
        for size in [CGSize(width: 1280, height: 720), CGSize(width: 1024, height: 600), CGSize(width: 800, height: 500)] {
            let visible = CGRect(origin: .zero, size: size)
            let fitted = SettingsWindowLayout.fittedFrame(
                CGRect(x: 50, y: -100, width: 1120, height: 760), visibleFrame: visible, minimumSize: minimum
            )
            XCTAssertTrue(visible.contains(fitted))
            XCTAssertGreaterThan(fitted.width, 0)
            XCTAssertGreaterThan(fitted.height, 0)
        }
    }

    func test_disconnectedMonitorFrameReturnsFullyOnScreen() {
        let visible = CGRect(x: 0, y: 40, width: 1440, height: 820)
        let fitted = SettingsWindowLayout.fittedFrame(
            CGRect(x: -1800, y: 500, width: 1120, height: 760), visibleFrame: visible, minimumSize: minimum
        )
        XCTAssertTrue(visible.contains(fitted))
    }

    func test_externalDisplayWithNegativeOriginPreservesUsersWindowSize() {
        let visible = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let frame = CGRect(x: -1700, y: 0, width: 1000, height: 600)
        XCTAssertEqual(SettingsWindowLayout.fittedFrame(frame, visibleFrame: visible, minimumSize: minimum), frame)
    }
}
