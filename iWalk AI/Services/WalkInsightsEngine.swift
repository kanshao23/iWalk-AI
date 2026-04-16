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

    /// Formats a pace value as "M:SS min/km".
    private static func formatPace(_ pace: Double) -> String {
        guard pace > 0, pace < 100 else { return "--:--" }
        let mins = Int(pace)
        let secs = Int((pace - Double(mins)) * 60)
        return String(format: "%d:%02d", mins, secs)
    }

    /// Average pace of up to the 5 most recent walks that have valid distance.
    private static func averagePace(from history: [WalkSession]) -> Double {
        let valid = history.filter { $0.paceMinPerKm > 0 }.prefix(5)
        guard !valid.isEmpty else { return 0 }
        return valid.map(\.paceMinPerKm).reduce(0, +) / Double(valid.count)
    }

    /// Returns nil when history < 3 walks (caller should use its own fallback).
    private static func insightText(
        history: [WalkSession],
        paceTrend: PaceTrend,
        bestTimeOfDay: TimeOfDay,
        weekComparison: WeekComparison
    ) -> String? {
        guard history.count >= 3 else { return nil }

        // 7+ walks AND known time of day → personal pattern
        if history.count >= 7 {
            let trendSuffix = paceTrend == .improving ? " — pace improving" : ""
            switch bestTimeOfDay {
            case .morning:
                return "You walk best in the morning\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
            case .afternoon:
                return "Afternoon is your sweet spot\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
            case .evening:
                return "Evening walks are your habit\(trendSuffix). \(weekComparison.thisWeekWalks) walks this week."
            case .unknown:
                break
            }
        }

        // 3–6 walks OR unknown time of day → consistency + pace
        let avg = averagePace(from: history)
        let paceStr = formatPace(avg)
        let count = weekComparison.thisWeekWalks
        let word = count == 1 ? "walk" : "walks"
        return "\(count) \(word) this week · avg pace \(paceStr) min/km"
    }

    /// Main entry point. insightText is nil when history < 3 walks.
    static func analyze(history: [WalkSession]) -> WalkInsightSummary {
        let trend = paceTrend(from: history)
        let tod   = bestTimeOfDay(from: history)
        let week  = weekComparison(from: history)
        let text  = insightText(history: history, paceTrend: trend,
                                bestTimeOfDay: tod, weekComparison: week)
        let avg   = averagePace(from: history)

        return WalkInsightSummary(
            insightText: text,
            paceTrend: trend,
            bestTimeOfDay: tod,
            weekComparison: week,
            totalWalks: history.count,
            avgPaceMinPerKm: avg
        )
    }

    /// Groups sessions into the current and previous calendar week (weekOfYear).
    static func weekComparison(from history: [WalkSession]) -> WeekComparison {
        let cal = Calendar.current
        let now = Date()
        guard let thisWeekInterval = cal.dateInterval(of: .weekOfYear, for: now) else {
            return WeekComparison(thisWeekWalks: 0, lastWeekWalks: 0,
                                  thisWeekSteps: 0, lastWeekSteps: 0)
        }
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1,
                                     to: thisWeekInterval.start)!

        let thisWeek = history.filter { thisWeekInterval.contains($0.startTime) }
        let lastWeek = history.filter {
            $0.startTime >= lastWeekStart && $0.startTime < thisWeekInterval.start
        }

        return WeekComparison(
            thisWeekWalks: thisWeek.count,
            lastWeekWalks: lastWeek.count,
            thisWeekSteps: thisWeek.map(\.steps).reduce(0, +),
            lastWeekSteps: lastWeek.map(\.steps).reduce(0, +)
        )
    }
}
