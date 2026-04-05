import Foundation

struct StreakData: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedDate: Date?
    var freezeCardsRemaining: Int
    var freezeCardsUsed: [Date]

    static let empty = StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastCompletedDate: nil,
        freezeCardsRemaining: 0,
        freezeCardsUsed: []
    )

    static let mock = StreakData(
        currentStreak: 14,
        longestStreak: 21,
        lastCompletedDate: Calendar.current.startOfDay(for: .now),
        freezeCardsRemaining: 2,
        freezeCardsUsed: []
    )

    var isActiveToday: Bool {
        guard let last = lastCompletedDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    var isAtRisk: Bool {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour >= 20 && !isActiveToday
    }

    var dailyCoinReward: Int {
        3 * min(currentStreak, 10)
    }

    static let milestones: [Int] = [7, 14, 30, 60, 100]

    var nextMilestone: Int? {
        Self.milestones.first { $0 > currentStreak }
    }

    var daysToNextMilestone: Int? {
        guard let next = nextMilestone else { return nil }
        return next - currentStreak
    }

    mutating func completeToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        if let last = lastCompletedDate {
            let lastDay = calendar.startOfDay(for: last)
            if calendar.isDateInToday(last) {
                return
            }
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween == 1 {
                currentStreak += 1
            } else if daysBetween == 2 && freezeCardsRemaining > 0 {
                freezeCardsRemaining -= 1
                freezeCardsUsed.append(calendar.date(byAdding: .day, value: -1, to: today) ?? today)
                currentStreak += 1
            } else {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }

        lastCompletedDate = today
        longestStreak = max(longestStreak, currentStreak)

        if currentStreak > 0 && currentStreak % 7 == 0 && freezeCardsRemaining < 3 {
            freezeCardsRemaining += 1
        }
    }
}
