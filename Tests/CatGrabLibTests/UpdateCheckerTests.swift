import XCTest
@testable import CatGrabLib

final class UpdateCheckerTests: XCTestCase {
    func test_version_comparesNumerically() throws {
        let old = try XCTUnwrap(AppVersion("1.9.0"))
        let new = try XCTUnwrap(AppVersion("1.10.0"))
        XCTAssertLessThan(old, new)
        XCTAssertEqual(AppVersion("1.4"), AppVersion("1.4.0"))
        XCTAssertEqual(AppVersion("v1.4.0"), AppVersion("1.4.0 (12)"))
    }

    func test_version_rejectsGarbage() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("latest"))
        XCTAssertNil(AppVersion("1..2"))
    }

    func test_evaluate_newerReleaseIsAvailable() {
        let json = Data(#"{"tag_name":"v1.5.0","html_url":"https://github.com/berbekk/CatGrab/releases/tag/v1.5.0"}"#.utf8)
        let page = URL(string: "https://github.com/berbekk/CatGrab/releases/tag/v1.5.0")!
        XCTAssertEqual(
            UpdateChecker.evaluate(releaseJSON: json, currentVersion: "1.4.0"),
            .available(AvailableUpdate(version: "1.5.0", pageURL: page))
        )
    }

    func test_evaluate_sameOrOlderReleaseIsUpToDate() {
        let json = Data(#"{"tag_name":"v1.4.0","html_url":"https://github.com/berbekk/CatGrab/releases/tag/v1.4.0"}"#.utf8)
        XCTAssertEqual(UpdateChecker.evaluate(releaseJSON: json, currentVersion: "1.4.0"), .upToDate)
        XCTAssertEqual(UpdateChecker.evaluate(releaseJSON: json, currentVersion: "1.5.0"), .upToDate)
    }

    func test_evaluate_prereleaseIsIgnored() {
        let json = Data(#"{"tag_name":"v2.0.0","prerelease":true}"#.utf8)
        XCTAssertEqual(UpdateChecker.evaluate(releaseJSON: json, currentVersion: "1.4.0"), .upToDate)
    }

    func test_evaluate_foreignPageFallsBackToReleasesPage() {
        let json = Data(#"{"tag_name":"v1.5.0","html_url":"https://example.com/CatGrab.dmg"}"#.utf8)
        guard case .available(let update) = UpdateChecker.evaluate(releaseJSON: json, currentVersion: "1.4.0") else {
            return XCTFail("expected an update")
        }
        XCTAssertEqual(update.pageURL.absoluteString, UpdateChecker.releasesPage)
    }

    func test_evaluate_unreadableResponse() {
        XCTAssertEqual(UpdateChecker.evaluate(releaseJSON: Data("<html>".utf8), currentVersion: "1.4.0"), .unreadable)
        XCTAssertEqual(UpdateChecker.evaluate(releaseJSON: Data(#"{"tag_name":"nightly"}"#.utf8), currentVersion: "1.4.0"), .unreadable)
    }

    func test_isCheckDue_onceADay() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(UpdateChecker.isCheckDue(lastCheck: nil, now: now))
        XCTAssertFalse(UpdateChecker.isCheckDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(UpdateChecker.isCheckDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now))
        XCTAssertTrue(UpdateChecker.isCheckDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }

    @MainActor
    func test_check_findsUpdate_andSkipSilencesIt() async throws {
        let suite = "UpdateCheckerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let checker = UpdateChecker(defaults: defaults, currentVersion: "1.4.0") { _ in
            Data(#"{"tag_name":"v1.6.0","html_url":"https://github.com/berbekk/CatGrab/releases/tag/v1.6.0"}"#.utf8)
        }
        XCTAssertFalse(checker.automaticChecksEnabled, "automatic checks are opt-in")

        await checker.check(userInitiated: true)
        let update = try XCTUnwrap(checker.updateToAnnounce)
        XCTAssertEqual(update.version, "1.6.0")

        checker.skip(update)
        XCTAssertNil(checker.updateToAnnounce)
        XCTAssertEqual(checker.state, .available(update), "the About card still offers the download")
    }

    @MainActor
    func test_check_networkFailure_isShownOnlyWhenUserAsked() async throws {
        let suite = "UpdateCheckerTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let checker = UpdateChecker(defaults: defaults, currentVersion: "1.4.0") { _ in
            throw URLError(.notConnectedToInternet)
        }
        await checker.check()
        XCTAssertEqual(checker.state, .idle)
        await checker.check(userInitiated: true)
        XCTAssertEqual(checker.state, .failed)
    }
}
