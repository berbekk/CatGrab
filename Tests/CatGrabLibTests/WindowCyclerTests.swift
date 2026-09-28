import XCTest
@testable import CatGrabLib

final class WindowCyclerTests: XCTestCase {
    func test_raisesTheBackmostWindowSoRepeatedCallsVisitEveryWindow() {
        // Three windows A(1) B(2) C(3), front to back. Raising the backmost each time goes
        // A → C → B → A: every window comes up, not just the top two.
        var zOrder: [CGWindowID] = [1, 2, 3]
        let axOrder: [CGWindowID?] = [1, 2, 3]
        var fronts: [CGWindowID] = []
        for _ in 0..<3 {
            guard let index = WindowCycler.indexToRaise(windowIDs: axOrder, zOrder: zOrder),
                  let id = axOrder[index] else { return XCTFail("nothing to raise") }
            zOrder.removeAll { $0 == id }
            zOrder.insert(id, at: 0)
            fronts.append(id)
        }
        XCTAssertEqual(fronts, [3, 2, 1])
    }

    func test_orderComesFromTheWindowServerNotFromAccessibility() {
        // Accessibility lists B first, but on screen A is on top and B is at the back.
        let index = WindowCycler.indexToRaise(windowIDs: [2, 1, 3], zOrder: [99, 1, 3, 42, 2])
        XCTAssertEqual(index, 0)
    }

    func test_windowsThatAreNotOnScreenAreSkipped() {
        // Window 3 is on another desktop or minimized: only 1 and 2 take part.
        XCTAssertEqual(WindowCycler.indexToRaise(windowIDs: [1, 2, 3], zOrder: [1, 2]), 1)
        XCTAssertNil(WindowCycler.indexToRaise(windowIDs: [1, 3], zOrder: [1]))
        XCTAssertNil(WindowCycler.indexToRaise(windowIDs: [nil, 1], zOrder: [1]))
        XCTAssertNil(WindowCycler.indexToRaise(windowIDs: [], zOrder: [1, 2]))
    }
}
