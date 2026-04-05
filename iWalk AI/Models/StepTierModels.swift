import Foundation

struct StepTier: Identifiable, Codable {
    let id: Int
    let stepsRequired: Int
    let coinReward: Int
    var isReached: Bool
    var isClaimed: Bool

    static let allTiers: [StepTier] = [
        StepTier(id: 1, stepsRequired: 1_500, coinReward: 5, isReached: false, isClaimed: false),
        StepTier(id: 2, stepsRequired: 3_000, coinReward: 8, isReached: false, isClaimed: false),
        StepTier(id: 3, stepsRequired: 6_500, coinReward: 12, isReached: false, isClaimed: false),
        StepTier(id: 4, stepsRequired: 10_000, coinReward: 18, isReached: false, isClaimed: false),
        StepTier(id: 5, stepsRequired: 20_000, coinReward: 25, isReached: false, isClaimed: false),
    ]
}

struct PersonalGoal: Codable {
    let targetSteps: Int
    let coinReward: Int
    var isReached: Bool

    static func calculate(from recentDailySteps: [Int]) -> PersonalGoal {
        let avg = recentDailySteps.isEmpty ? 8_000 : recentDailySteps.reduce(0, +) / recentDailySteps.count
        let target = Int(Double(avg) * 1.1)
        return PersonalGoal(targetSteps: target, coinReward: 10, isReached: false)
    }

    static let mock = PersonalGoal(targetSteps: 9_350, coinReward: 10, isReached: false)
}
