import SwiftUI
import WidgetKit

@Observable
final class DashboardViewModel {
    var user = UserProfile.mock
    var todayStats = DailyStats(date: .now, steps: 0, calories: 0, distanceKm: 0, activeMinutes: 0, heartRate: nil)
    var weeklyActivity = DailyStats.mockWeek
    var hasLoadedRealData = false
    var isDistanceEstimated = true
    var isCaloriesEstimated = true
    var healthTips = HealthTip.mockTips
    var currentTipIndex = 0

    // Animation states
    var animatedProgress: Double = 0
    var animatedSteps: Int = 0
    var showHistory = false
    var showActiveWalk = false

    // Evening review
    var eveningReview: EveningReview?
    var showEveningDetails = false

    // Journey detail
    var showJourneyDetail = false

    var isWalking: Bool { showActiveWalk }
    var stepGoal: Int { user.dailyStepGoal }
    var currentSteps: Int { todayStats.steps }
    var targetProgress: Double { min(Double(currentSteps) / Double(stepGoal), 1.0) }

    var isEveningMode: Bool {
        Calendar.current.component(.hour, from: .now) >= 20
    }

    var currentTip: HealthTip {
        healthTips[currentTipIndex % healthTips.count]
    }

    var todayWeekdayIndex: Int {
        Calendar.current.component(.weekday, from: .now) - 1
    }

    var chartData: [CGFloat] {
        let maxSteps = CGFloat(weeklyActivity.map(\.steps).max() ?? 1)
        return weeklyActivity.map { CGFloat($0.steps) / maxSteps }
    }

    var chartLabels: [String] {
        weeklyActivity.map(\.shortDayName)
    }

    var weeklyAvgSteps: Int {
        let total = weeklyActivity.map(\.steps).reduce(0, +)
        return weeklyActivity.isEmpty ? 0 : total / weeklyActivity.count
    }

    private let healthKit = HealthKitManager.shared
    private var refreshTimer: Timer?

    // MARK: - Auto Refresh (every 30s + foreground)

    func startAutoRefresh(coinVM: CoinViewModel, streakVM: StreakViewModel) {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshFromHealthKit(coinVM: coinVM, streakVM: streakVM)
        }
    }

    func setupNotifications() {
        // No-op now. Walk completion is committed locally first, then refreshed by timer/foreground.
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refreshFromHealthKit(coinVM: CoinViewModel, streakVM: StreakViewModel) {
        Task {
            let steps = await healthKit.fetchTodaySteps()
            let distance = await healthKit.fetchTodayDistance()
            let calories = await healthKit.fetchTodayCalories()
            let shouldUseRealData = healthKit.hasRequestedAuthorization || steps > 0 || distance > 0 || calories > 0
            guard shouldUseRealData else { return }

            await MainActor.run {
                todayStats.steps = steps
                if distance > 0 {
                    todayStats.distanceKm = distance
                    isDistanceEstimated = false
                } else {
                    todayStats.distanceKm = Double(steps) / 1400.0
                    isDistanceEstimated = true
                }
                if calories > 0 {
                    todayStats.calories = calories
                    isCaloriesEstimated = false
                } else {
                    todayStats.calories = steps / 20
                    isCaloriesEstimated = true
                }
                todayStats.activeMinutes = steps / 200

                withAnimation(.easeOut(duration: 0.3)) {
                    animatedSteps = todayStats.steps
                    animatedProgress = targetProgress
                }

                WidgetCenter.shared.reloadAllTimelines()

                // Check tiers & streak with latest steps
                coinVM.checkStepTiers(currentSteps: steps)
                if steps >= 1500 {
                    streakVM.completeTodayIfNeeded(coinVM: coinVM)
                }
            }
        }
    }

    func animateOnAppear() {
        withAnimation(.easeOut(duration: 1.2)) {
            animatedProgress = targetProgress
        }
        animateStepCount()
    }

    /// Load real data from HealthKit (falls back to mock if unavailable)
    func loadRealData() async {
        let steps = await healthKit.fetchTodaySteps()
        let distance = await healthKit.fetchTodayDistance()
        let calories = await healthKit.fetchTodayCalories()
        let weekly = await healthKit.fetchWeeklySteps()
        let shouldUseRealData = healthKit.hasRequestedAuthorization || steps > 0 || distance > 0 || calories > 0 || !weekly.isEmpty
        guard shouldUseRealData else { return }

        await MainActor.run {
            hasLoadedRealData = true
            todayStats.steps = steps
            if distance > 0 {
                todayStats.distanceKm = distance
                isDistanceEstimated = false
            } else {
                todayStats.distanceKm = Double(steps) / 1400.0
                isDistanceEstimated = true
            }
            if calories > 0 {
                todayStats.calories = calories
                isCaloriesEstimated = false
            } else {
                todayStats.calories = steps / 20
                isCaloriesEstimated = true
            }
            todayStats.activeMinutes = steps / 200
            if !weekly.isEmpty {
                weeklyActivity = weekly
            }
            // Re-animate with real values
            animatedSteps = todayStats.steps
            withAnimation(.easeOut(duration: 0.6)) {
                animatedProgress = targetProgress
            }
        }
    }

    private func animateStepCount() {
        let duration = 1.2
        let steps = 40
        let stepInterval = duration / Double(steps)
        let stepIncrement = currentSteps / max(steps, 1)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval * Double(i)) { [weak self] in
                guard let self else { return }
                if i == steps {
                    self.animatedSteps = self.currentSteps
                } else {
                    self.animatedSteps = stepIncrement * i
                }
            }
        }
    }

    func startWalking() {
        Task {
            if !healthKit.hasRequestedAuthorization {
                _ = await healthKit.requestAuthorization()
            }
            await MainActor.run {
                showActiveWalk = true
            }
        }
    }

    func onWalkCompleted(session: WalkSession) {
        todayStats.steps = session.totalSteps
        todayStats.calories = todayStats.steps / 20
        todayStats.distanceKm = Double(todayStats.steps) / 1400.0
        todayStats.activeMinutes = todayStats.steps / 200

        animatedSteps = todayStats.steps
        withAnimation(.easeOut(duration: 0.6)) {
            animatedProgress = targetProgress
        }

        showActiveWalk = false
    }

    func generateEveningReview(coinVM: CoinViewModel, streakVM: StreakViewModel, journeyVM: JourneyViewModel) {
        guard isEveningMode && eveningReview == nil else { return }

        eveningReview = EveningReview.generate(
            steps: currentSteps,
            tiers: coinVM.highestTierReached,
            coins: coinVM.todayEarnings,
            streak: streakVM.streak.currentStreak,
            journeyDistance: journeyVM.todayDistanceKm,
            nextCity: journeyVM.activeJourney?.nextMilestone?.name,
            distanceRemaining: journeyVM.activeJourney?.distanceToNextMilestone,
            weeklyAvgSteps: weeklyAvgSteps
        )
    }

    func claimReviewCoins(coinVM: CoinViewModel) {
        guard var review = eveningReview, !review.isViewed else { return }
        review.isViewed = true
        eveningReview = review
        coinVM.earn(amount: 5, source: .dailyReview, description: "Viewed daily review")
    }

    func nextTip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTipIndex = (currentTipIndex + 1) % healthTips.count
        }
    }

    func previousTip() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTipIndex = (currentTipIndex - 1 + healthTips.count) % healthTips.count
        }
    }
}
