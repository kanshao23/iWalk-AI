import SwiftUI

@Observable
final class StreakViewModel {
    var streak: StreakData

    var showMilestoneToast = false
    var reachedMilestone: Int?

    private let storageKey = "iw_streak_data"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(StreakData.self, from: data) {
            self.streak = saved
        } else {
            self.streak = .mock
        }
    }

    func completeTodayIfNeeded(coinVM: CoinViewModel) {
        guard !streak.isActiveToday else { return }

        let previousStreak = streak.currentStreak
        streak.completeToday()

        let reward = streak.dailyCoinReward
        if reward > 0 {
            coinVM.earn(
                amount: reward,
                source: .streak,
                description: "\(streak.currentStreak)-day streak bonus"
            )
        }

        if StreakData.milestones.contains(streak.currentStreak) && streak.currentStreak > previousStreak {
            reachedMilestone = streak.currentStreak
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showMilestoneToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                withAnimation(.easeOut(duration: 0.3)) {
                    self?.showMilestoneToast = false
                }
            }
        }

        save()
    }

    func useFreezeCard() {
        guard streak.freezeCardsRemaining > 0 else { return }
        streak.freezeCardsRemaining -= 1
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(streak) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
