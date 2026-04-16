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
        comps.day! -= daysAgo
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
}
