import XCTest
@testable import CatGrabLib

final class OnboardingTests: XCTestCase {
    func test_pagesRunInOrderAndEndOnDone() {
        var page: OnboardingPage? = .welcome
        var visited: [OnboardingPage] = []
        while let current = page {
            visited.append(current)
            page = current.next
        }
        XCTAssertEqual(visited, OnboardingPage.allCases)
        XCTAssertEqual(visited.last, .done)
        XCTAssertTrue(OnboardingPage.done.isLast)
        XCTAssertNil(OnboardingPage.welcome.previous)
        XCTAssertEqual(OnboardingPage.done.previous, .permissions)
    }

    func test_permissionsComeRightBeforeTheEnd() {
        XCTAssertEqual(OnboardingPage.permissions.next, .done)
    }

    func test_firstLaunchGetsTheTourAndReturningUsersOnlyThePermissionsPageWhenNeeded() {
        XCTAssertEqual(
            AppLaunchState.onboardingEntry(hasCompletedOnboarding: false, accessibilityGranted: true, needsAccessibility: false),
            .tour
        )
        XCTAssertEqual(
            AppLaunchState.onboardingEntry(hasCompletedOnboarding: true, accessibilityGranted: false, needsAccessibility: true),
            .permissions
        )
        XCTAssertNil(AppLaunchState.onboardingEntry(hasCompletedOnboarding: true, accessibilityGranted: true, needsAccessibility: true))
        XCTAssertNil(AppLaunchState.onboardingEntry(hasCompletedOnboarding: true, accessibilityGranted: false, needsAccessibility: false))
    }

    func test_afterRelaunchIntentRoundTrips() {
        let previous = AppLaunchState.afterRelaunch
        defer { AppLaunchState.afterRelaunch = previous }
        AppLaunchState.afterRelaunch = .openSettingsWithReadyBanner
        XCTAssertEqual(AppLaunchState.afterRelaunch, .openSettingsWithReadyBanner)
        AppLaunchState.afterRelaunch = nil
        XCTAssertNil(AppLaunchState.afterRelaunch)
    }
}
