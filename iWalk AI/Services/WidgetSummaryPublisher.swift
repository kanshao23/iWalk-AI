import Foundation

enum WidgetSummaryPublisher {
    private static let suiteName = "group.kanshaous.iWalkAI"
    private static let snapshotKey = "iw_widget_summary_snapshot_v1"

    static func publish(todayStats: DailyStats, goal: Int) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }

        let snapshot = WidgetSummarySnapshot(
            updatedAt: .now,
            steps: todayStats.steps,
            distanceKm: todayStats.distanceKm,
            calories: todayStats.calories,
            dailyGoal: goal
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    static func clear() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: snapshotKey)
    }
}

private struct WidgetSummarySnapshot: Codable {
    let updatedAt: Date
    let steps: Int
    let distanceKm: Double
    let calories: Int
    let dailyGoal: Int
}
