import SwiftUI

@Observable
final class BadgesViewModel {
    var badges = Badge.mockBadges
    var challenges = Challenge.mockChallenges

    // Local comparison data
    var thisWeekDaily: [DailyStats] = []
    var lastWeekDaily: [DailyStats] = []
    var isLoadingComparison = false

    // UI States
    var selectedBadge: Badge?
    var expandedChallengeId: UUID?
    var challengeAnimated: [UUID: Bool] = [:]

    var thisWeekAvg: Int {
        guard !thisWeekDaily.isEmpty else { return 0 }
        return thisWeekDaily.map(\.steps).reduce(0, +) / thisWeekDaily.count
    }

    var lastWeekAvg: Int {
        guard !lastWeekDaily.isEmpty else { return 0 }
        return lastWeekDaily.map(\.steps).reduce(0, +) / lastWeekDaily.count
    }

    var weekOverWeekPercent: Int {
        guard lastWeekAvg > 0 else { return 0 }
        return Int(((Double(thisWeekAvg) - Double(lastWeekAvg)) / Double(lastWeekAvg)) * 100)
    }

    var comparisonMessage: String {
        let pct = weekOverWeekPercent
        if pct > 0 { return "\(pct)% more than last week — keep it up!" }
        else if pct < 0 { return "\(abs(pct))% less than last week — push today!" }
        else { return "Same as last week — stay consistent!" }
    }

    @MainActor
    func loadComparisonData() async {
        let healthKit = HealthKitManager.shared
        guard healthKit.isAuthorized else { return }
        isLoadingComparison = true
        async let thisWeek = healthKit.fetchWeeklySteps()
        async let lastWeek = healthKit.fetchPreviousWeekSteps()
        thisWeekDaily = await thisWeek
        lastWeekDaily = await lastWeek
        isLoadingComparison = false
    }

    var unlockedBadges: [Badge] {
        badges.filter(\.isUnlocked)
    }

    var lockedBadges: [Badge] {
        badges.filter { !$0.isUnlocked }
    }

    func animateOnAppear() {
        for challenge in challenges {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.8)) {
                    self.challengeAnimated[challenge.id] = true
                }
            }
        }
    }

    func toggleChallenge(_ challenge: Challenge) {
        if let index = challenges.firstIndex(where: { $0.id == challenge.id }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                challenges[index].isJoined.toggle()
            }
        }
    }

    func toggleExpandChallenge(_ challenge: Challenge) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedChallengeId == challenge.id {
                expandedChallengeId = nil
            } else {
                expandedChallengeId = challenge.id
            }
        }
    }
}
