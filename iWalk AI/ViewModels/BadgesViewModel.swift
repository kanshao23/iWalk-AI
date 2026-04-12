import SwiftUI

@Observable
final class BadgesViewModel {
    var badges: [Badge] = Badge.mockBadges
    var challenges: [Challenge] = Challenge.mockChallenges

    var thisWeekDaily: [DailyStats] = []
    var lastWeekDaily: [DailyStats] = []
    var isLoadingComparison = false

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
        if pct > 0  { return "\(pct)% more than last week — keep it up!" }
        if pct < 0  { return "\(abs(pct))% less than last week — push today!" }
        return "Same as last week — stay consistent!"
    }

    var unlockedBadges: [Badge] { badges.filter(\.isUnlocked) }
    var lockedBadges:   [Badge] { badges.filter { !$0.isUnlocked } }

    // MARK: - Real Data Loading

    @MainActor
    func loadComparisonData() async {
        let hk = HealthKitManager.shared
        isLoadingComparison = true

        async let thisWeekTask = hk.isAuthorized ? hk.fetchWeeklySteps() : []
        async let prevWeekTask = hk.isAuthorized ? hk.fetchPreviousWeekSteps() : []
        let todaySteps = hk.isAuthorized ? await hk.fetchTodaySteps() : 0

        let (thisWeekData, prevWeekData) = await (thisWeekTask, prevWeekTask)
        thisWeekDaily = thisWeekData
        lastWeekDaily = prevWeekData

        let history        = ActiveWalkViewModel.loadHistory()
        let weeklyTotal    = thisWeekData.map(\.steps).reduce(0, +)
        let prevWeekTotal  = prevWeekData.map(\.steps).reduce(0, +)
        let activeDays     = thisWeekData.filter { $0.steps >= 8_000 }.count

        badges     = computeBadges(history: history, todaySteps: todaySteps, weeklyData: thisWeekData)
        challenges = computeChallenges(weeklyTotal: weeklyTotal, prevWeekTotal: prevWeekTotal, activeDays: activeDays, todaySteps: todaySteps)

        isLoadingComparison = false
    }

    // MARK: - Badge Computation

    private func computeBadges(history: [WalkSession], todaySteps: Int, weeklyData: [DailyStats]) -> [Badge] {
        let calendar = Calendar.current

        // First Steps
        let hasWalked = !history.isEmpty

        // Early Bird – any walk started before 7 AM
        let earlyWalk = history.first { calendar.component(.hour, from: $0.startTime) < 7 }

        // Night Owl – any walk started at 22:00 or later
        let nightWalk = history.first { calendar.component(.hour, from: $0.startTime) >= 22 }

        // 10k Club – highest single-day step count
        let maxDaySteps = max(todaySteps, weeklyData.map(\.steps).max() ?? 0,
                              history.map(\.totalSteps).max() ?? 0)

        // Half Marathon – cumulative walk distance
        let totalWalkKm  = history.map(\.distanceKm).reduce(0, +)

        return [
            Badge(
                name: "First Steps", icon: "figure.walk", color: .iwPrimary,
                description: "Complete your very first walk session",
                requirement: "Start 1 walk",
                isUnlocked: hasWalked,
                unlockedDate: history.first?.startTime,
                progress: hasWalked ? 1.0 : 0.0
            ),
            Badge(
                name: "10k Club", icon: "star.fill", color: .iwPrimaryFixed,
                description: "Hit 10,000 steps in a single day",
                requirement: "10,000 steps in one day",
                isUnlocked: maxDaySteps >= 10_000,
                unlockedDate: maxDaySteps >= 10_000 ? .now : nil,
                progress: min(Double(maxDaySteps) / 10_000.0, 1.0)
            ),
            Badge(
                name: "Early Bird", icon: "sunrise.fill", color: .iwTertiaryContainer,
                description: "Complete a walk before 7:00 AM",
                requirement: "Walk before 7 AM",
                isUnlocked: earlyWalk != nil,
                unlockedDate: earlyWalk?.startTime,
                progress: earlyWalk != nil ? 1.0 : 0.0
            ),
            Badge(
                name: "Half Marathon", icon: "medal.fill", color: .iwSecondaryFixedDim,
                description: "Walk a total of 21.1 km across all your sessions",
                requirement: "21.1 km cumulative",
                isUnlocked: totalWalkKm >= 21.1,
                unlockedDate: totalWalkKm >= 21.1 ? .now : nil,
                progress: min(totalWalkKm / 21.1, 1.0)
            ),
            Badge(
                name: "Night Owl", icon: "moon.stars.fill", color: .iwInverseSurface,
                description: "Complete a walk after 10:00 PM",
                requirement: "Walk after 10 PM",
                isUnlocked: nightWalk != nil,
                unlockedDate: nightWalk?.startTime,
                progress: nightWalk != nil ? 1.0 : 0.0
            ),
            Badge(
                name: "Calorie Crusher", icon: "flame.fill", color: .iwTertiaryFixedDim,
                description: "Burn 500+ calories in a single walk session",
                requirement: "500 kcal in one walk",
                isUnlocked: history.contains { $0.calories >= 500 },
                unlockedDate: history.first(where: { $0.calories >= 500 })?.startTime,
                progress: min(Double(history.map(\.calories).max() ?? 0) / 500.0, 1.0)
            ),
        ]
    }

    // MARK: - Challenge Computation

    private func computeChallenges(weeklyTotal: Int, prevWeekTotal: Int, activeDays: Int, todaySteps: Int) -> [Challenge] {
        let calendar = Calendar.current
        let now = Date.now
        let weekday = calendar.component(.weekday, from: now)
        let daysToSunday = (8 - weekday) % 7
        let endOfWeek = calendar.date(byAdding: .day, value: daysToSunday == 0 ? 7 : daysToSunday, to: now)

        return [
            Challenge(
                name: "Weekly 50k",
                description: "Walk 50,000 steps this week. Every step counts toward this milestone.",
                icon: "figure.walk", iconColor: .iwPrimary,
                goalValue: 50_000, currentValue: weeklyTotal,
                unit: "steps", deadline: endOfWeek, isJoined: true
            ),
            Challenge(
                name: "5 Active Days",
                description: "Stay active for 5 days this week — at least 8,000 steps each day.",
                icon: "calendar.badge.checkmark", iconColor: .iwSecondary,
                goalValue: 5, currentValue: activeDays,
                unit: "days", deadline: endOfWeek, isJoined: true
            ),
            Challenge(
                name: "Beat Last Week",
                description: prevWeekTotal > 0
                    ? "Top your previous week total of \(prevWeekTotal.formatted()) steps."
                    : "Set your first weekly step benchmark.",
                icon: "chart.line.uptrend.xyaxis", iconColor: .iwTertiary,
                goalValue: max(prevWeekTotal, 10_000),
                currentValue: weeklyTotal,
                unit: "steps", deadline: endOfWeek, isJoined: prevWeekTotal > 0
            ),
        ]
    }

    // MARK: - UI Actions

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
            expandedChallengeId = expandedChallengeId == challenge.id ? nil : challenge.id
        }
    }
}
