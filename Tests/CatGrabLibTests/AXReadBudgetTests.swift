import XCTest
@testable import CatGrabLib

final class AXReadBudgetTests: XCTestCase {
    func test_laterRequestsOnlyGetTheRemainingTime() throws {
        let budget = AXReadBudget(duration: 0.35, now: 100)
        XCTAssertEqual(try XCTUnwrap(budget.timeout(at: 100)), 0.2, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(budget.timeout(at: 100.30)), 0.05, accuracy: 0.0001)
        XCTAssertNil(budget.timeout(at: 100.35))
        XCTAssertNil(budget.timeout(at: 101))
    }

    func test_expiredOrInvalidBudgetsNeverReturnAXZeroTimeout() {
        for duration in [0, -1, Double.nan, .infinity] {
            XCTAssertNil(AXReadBudget(duration: duration, now: 100).timeout(at: 100))
        }
    }
}
