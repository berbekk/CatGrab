import XCTest
@testable import CatGrabLib

final class RunningAppsLimitTests: XCTestCase {
    private let alphabetical = ["Finder", "Mail", "Notes", "Safari", "Terminal", "Xcode", "Zed"]

    func test_noLimitOrEnoughRoomKeepsEveryApp() {
        XCTAssertEqual(RunningAppsMenuItems.limited(alphabetical, recent: ["Zed"], pinned: nil, limit: 0), alphabetical)
        XCTAssertEqual(RunningAppsMenuItems.limited(alphabetical, recent: [], pinned: nil, limit: 7), alphabetical)
    }

    func test_keepsTheMostRecentAppsInAlphabeticalOrder() {
        let kept = RunningAppsMenuItems.limited(alphabetical, recent: ["Zed", "Mail", "Xcode"], pinned: nil, limit: 3)
        XCTAssertEqual(kept, ["Mail", "Xcode", "Zed"])
    }

    func test_pinnedAppSurvivesEvenIfItIsNotRecentAndGapsFillAlphabetically() {
        let kept = RunningAppsMenuItems.limited(alphabetical, recent: ["Zed"], pinned: "Terminal", limit: 3)
        XCTAssertEqual(kept, ["Finder", "Terminal", "Zed"])
    }

    func test_limitRoundTripsAndDefaultsToSixForOldConfigs() throws {
        var menu = PieConfiguration.templateRunningAppsMenu()
        XCTAssertEqual(menu.runningAppsLimit, 6)
        menu.runningAppsLimit = 0
        let decoded = try JSONDecoder().decode(PieMenu.self, from: try JSONEncoder().encode(menu))
        XCTAssertEqual(decoded.runningAppsLimit, 0)

        let json = try XCTUnwrap(String(data: try JSONEncoder().encode(menu), encoding: .utf8))
            .replacingOccurrences(of: "\"runningAppsLimit\":0,", with: "")
            .replacingOccurrences(of: ",\"runningAppsLimit\":0", with: "")
        XCTAssertEqual(try JSONDecoder().decode(PieMenu.self, from: Data(json.utf8)).runningAppsLimit, 6)
        XCTAssertEqual(PieMenu.clampedRunningAppsLimit(-3), 0)
        XCTAssertEqual(PieMenu.clampedRunningAppsLimit(1), PieMenuItem.minItemCount)
    }
}
