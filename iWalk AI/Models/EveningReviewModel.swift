import Foundation

struct EveningReview: Codable {
    let date: Date
    let totalSteps: Int
    let tiersReached: Int
    let coinsEarned: Int
    let streakCount: Int
    let journeyDistanceToday: Double
    let journeyNextCity: String?
    let journeyDistanceRemaining: Double?
    let aiSummary: String
    let comparisonToAverage: Int
    var isViewed: Bool

    static func generate(
        steps: Int,
        tiers: Int,
        coins: Int,
        streak: Int,
        journeyDistance: Double,
        nextCity: String?,
        distanceRemaining: Double?,
        weeklyAvgSteps: Int
    ) -> EveningReview {
        let comparison = weeklyAvgSteps > 0
            ? Int((Double(steps - weeklyAvgSteps) / Double(weeklyAvgSteps)) * 100)
            : 0

        let summary = generateAISummary(steps: steps, comparison: comparison, streak: streak)

        return EveningReview(
            date: .now,
            totalSteps: steps,
            tiersReached: tiers,
            coinsEarned: coins,
            streakCount: streak,
            journeyDistanceToday: journeyDistance,
            journeyNextCity: nextCity,
            journeyDistanceRemaining: distanceRemaining,
            aiSummary: summary,
            comparisonToAverage: comparison,
            isViewed: false
        )
    }

    private static func generateAISummary(steps: Int, comparison: Int, streak: Int) -> String {
        var parts: [String] = []

        if comparison > 0 {
            parts.append("You're \(comparison)% above your weekly average — great consistency!")
        } else if comparison < -10 {
            parts.append("A lighter day, but every step counts.")
        } else {
            parts.append("Solid effort — right on track with your weekly pace.")
        }

        if streak >= 7 {
            parts.append("Your \(streak)-day streak shows real commitment.")
        }

        let tips = [
            "Try a morning walk tomorrow for better sleep quality.",
            "Walking after meals helps regulate blood sugar.",
            "A brisk 10-minute walk boosts energy for 2 hours.",
            "Outdoor walks in nature reduce stress hormones by 15%.",
        ]
        parts.append(tips[abs(steps) % tips.count])

        return parts.joined(separator: " ")
    }
}
