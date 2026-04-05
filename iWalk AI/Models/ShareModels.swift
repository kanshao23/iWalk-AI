import Foundation

enum ShareCardType: String {
    case dailySummary
    case streakMilestone
    case journeyMilestone
    case badgeUnlock
    case challengeComplete
    case weeklyReport

    var defaultHeadline: String {
        switch self {
        case .dailySummary: "Daily Achievement"
        case .streakMilestone: "Streak Milestone!"
        case .journeyMilestone: "Journey Progress"
        case .badgeUnlock: "Badge Unlocked!"
        case .challengeComplete: "Challenge Complete!"
        case .weeklyReport: "Weekly Report"
        }
    }
}

struct ShareCardStats {
    let type: ShareCardType
    let headline: String
    let steps: Int?
    let distance: Double?
    let coins: Int?
    let extraLine: String?

    static func dailySummary(steps: Int, distance: Double, coins: Int) -> ShareCardStats {
        ShareCardStats(type: .dailySummary, headline: "\(steps.formatted()) Steps Today!", steps: steps, distance: distance, coins: coins, extraLine: nil)
    }

    static func streakMilestone(days: Int) -> ShareCardStats {
        ShareCardStats(type: .streakMilestone, headline: "\(days)-Day Streak!", steps: nil, distance: nil, coins: nil, extraLine: "Walking every day for \(days) days straight")
    }

    static func journeyMilestone(cityName: String, totalDistance: Double) -> ShareCardStats {
        ShareCardStats(type: .journeyMilestone, headline: "Reached \(cityName)!", steps: nil, distance: totalDistance, coins: nil, extraLine: "Walked the equivalent of \(String(format: "%.0f", totalDistance)) km")
    }

    static func badgeUnlock(badgeName: String) -> ShareCardStats {
        ShareCardStats(type: .badgeUnlock, headline: badgeName, steps: nil, distance: nil, coins: nil, extraLine: "New badge unlocked!")
    }
}
