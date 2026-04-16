import XCTest
@testable import iWalk_AI

final class WalkInsightsEngineTests: XCTestCase {

    // MARK: - Helper

    /// Creates a WalkSession with controlled start time and pace.
    private func makeSession(
        startHour: Int = 8,
        daysAgo: Int = 0,
        distanceKm: Double = 3.0,
        elapsedSeconds: Int = 1500
    ) -> WalkSession {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day = (comps.day ?? 0) - daysAgo
        comps.hour = startHour
        comps.minute = 0
        let start = Calendar.current.date(from: comps)!
        return WalkSession(
            startTime: start,
            endTime: start.addingTimeInterval(Double(elapsedSeconds)),
            steps: Int(distanceKm * 1350),
            calories: Int(distanceKm * 1350) / 20,
            distanceKm: distanceKm,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: 10_000,
            stepsBeforeWalk: 2_000,
            averageHeartRate: 75,
            routePoints: nil
        )
    }

    // MARK: - paceTrend

    func test_paceTrend_improving_whenRecentFasterByMoreThan5Pct() {
        // Recent 3: pace 6.67 min/km, Previous 3: pace 8.33 min/km → change = -0.20 → improving
        let recent   = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1200) }
        let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
        XCTAssertEqual(WalkInsightsEngine.paceTrend(from: recent + previous), .improving)
    }

    func test_paceTrend_declining_whenRecentSlowerByMoreThan5Pct() {
        // Recent 3: pace 10.0 min/km, Previous 3: pace 8.33 min/km → change = +0.20 → declining
        let recent   = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1800) }
        let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
        XCTAssertEqual(WalkInsightsEngine.paceTrend(from: recent + previous), .declining)
    }

    func test_paceTrend_stable_whenDifferenceLessThan5Pct() {
        // Recent 3: pace 8.50 min/km, Previous 3: pace 8.33 min/km → change = +0.02 → stable
        let recent   = (0..<3).map { makeSession(daysAgo: $0, elapsedSeconds: 1530) }
        let previous = (3..<6).map { makeSession(daysAgo: $0, elapsedSeconds: 1500) }
        XCTAssertEqual(WalkInsightsEngine.paceTrend(from: recent + previous), .stable)
    }

    func test_paceTrend_stable_whenFewerThan6WalksWithPace() {
        let history = (0..<5).map { makeSession(daysAgo: $0) }
        XCTAssertEqual(WalkInsightsEngine.paceTrend(from: history), .stable)
    }
}
