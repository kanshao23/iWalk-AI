import XCTest
@testable import iWalk_AI

final class HealthDataPresenceTests: XCTestCase {
    func testDashboardTreatsEmptyMetricsAsMockData() {
        XCTAssertFalse(
            HealthDataPresence.hasDashboardRealData(
                steps: 0,
                distanceKm: 0,
                calories: 0,
                weeklyCount: 0
            )
        )
    }

    func testCoachTreatsAuthorizationFlagAloneAsInsufficient() {
        XCTAssertFalse(
            HealthDataPresence.hasCoachRealData(
                steps: 0,
                weeklyCount: 0,
                heartRate: nil as Int?
            )
        )
    }
}
