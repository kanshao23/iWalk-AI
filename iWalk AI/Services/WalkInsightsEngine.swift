import Foundation

enum PaceTrend: String {
    case improving, stable, declining
}

enum TimeOfDay: String {
    case morning, afternoon, evening, unknown
}

struct WeekComparison {
    let thisWeekWalks: Int
    let lastWeekWalks: Int
    let thisWeekSteps: Int
    let lastWeekSteps: Int
}

struct WalkInsightSummary {
    /// Ready-to-display string. nil when history < 3 walks (caller uses fallback).
    let insightText: String?
    let paceTrend: PaceTrend
    let bestTimeOfDay: TimeOfDay
    let weekComparison: WeekComparison
    let totalWalks: Int
    let avgPaceMinPerKm: Double
}

struct WalkInsightsEngine {

    /// Compares average pace of the 3 most recent walks vs the 3 before them.
    /// Requires ≥6 walks with distance > 0.01 km; returns .stable otherwise.
    static func paceTrend(from history: [WalkSession]) -> PaceTrend {
        let withPace = history.filter { $0.paceMinPerKm > 0 }
        guard withPace.count >= 6 else { return .stable }

        let recentPaces   = withPace.prefix(3).map(\.paceMinPerKm)
        let previousPaces = withPace.dropFirst(3).prefix(3).map(\.paceMinPerKm)

        let recentAvg = recentPaces.reduce(0, +) / Double(recentPaces.count)
        let prevAvg   = previousPaces.reduce(0, +) / Double(previousPaces.count)
        guard prevAvg > 0 else { return .stable }

        let change = (recentAvg - prevAvg) / prevAvg
        if change < -0.05 { return .improving }
        if change >  0.05 { return .declining }
        return .stable
    }
}
