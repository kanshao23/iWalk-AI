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

    /// Returns the time bracket with ≥3 walks. Returns .unknown if none qualifies or total < 3.
    static func bestTimeOfDay(from history: [WalkSession]) -> TimeOfDay {
        guard history.count >= 3 else { return .unknown }

        var counts: [TimeOfDay: Int] = [.morning: 0, .afternoon: 0, .evening: 0]
        let cal = Calendar.current
        for session in history {
            let hour = cal.component(.hour, from: session.startTime)
            switch hour {
            case 5..<12:  counts[.morning,   default: 0] += 1
            case 12..<18: counts[.afternoon, default: 0] += 1
            case 18..<24: counts[.evening,   default: 0] += 1
            default: break
            }
        }

        guard let winner = counts.max(by: { $0.value < $1.value }),
              winner.value >= 3 else { return .unknown }
        return winner.key
    }
}
