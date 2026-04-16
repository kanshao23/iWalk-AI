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
    // Implementation added in later tasks
}
