import SwiftUI

@Observable
final class InsightsViewModel {
    var selectedCategory: MetricCategory = .heart
    var insights: [MetricCategory: InsightCard] = InsightCard.mockInsights
    var weeklySummary = WeeklySummary.mock
    var recommendedFocus = RecommendedFocus.mockByCategory
    var coachRecommendations = CoachRecommendation.mockRecommendations
    var expandedCoachRecommendationId: UUID?
    var natureTipTitle = "Nature tip"
    var natureTipDescription = "A short park walk can reduce stress more effectively than a dense urban route."
    var weeklyReport: WeeklyReport? = nil
    var isLoadingData = false

    var chartAnimated = false
    var cardsVisible = false

    var currentInsight: InsightCard? { insights[selectedCategory] }
    var currentFocus: RecommendedFocus? { recommendedFocus[selectedCategory] }

    // MARK: - Real Data Loading

    func loadRealData() async {
        let hk = HealthKitManager.shared

        isLoadingData = true

        async let thisWeekTask  = hk.fetchWeeklySteps()
        async let prevWeekTask  = hk.fetchPreviousWeekSteps()
        async let heartRateTask = hk.fetchLatestHeartRate()

        let (weekly, prevWeek, heartRate) = await (thisWeekTask, prevWeekTask, heartRateTask)
        let shouldUseRealData = HealthDataPresence.hasInsightsRealData(
            weeklyCount: weekly.count,
            heartRate: heartRate
        )
        guard shouldUseRealData else {
            insights = InsightCard.mockInsights
            weeklySummary = WeeklySummary.mock
            recommendedFocus = RecommendedFocus.mockByCategory
            coachRecommendations = CoachRecommendation.mockRecommendations
            weeklyReport = nil
            chartAnimated = false
            cardsVisible = false
            isLoadingData = false
            return
        }

        insights             = generateInsights(weekly: weekly, heartRate: heartRate)
        weeklySummary        = generateWeeklySummary(weekly: weekly, prevWeek: prevWeek)
        coachRecommendations = generateRecommendations(weekly: weekly, heartRate: heartRate)
        weeklyReport         = generateWeeklyReport(weekly: weekly, prevWeek: prevWeek, heartRate: heartRate)

        isLoadingData = false
        animateOnAppear()
    }

    // MARK: - Insight Generation

    private func generateInsights(weekly: [DailyStats], heartRate: Int?) -> [MetricCategory: InsightCard] {
        let totalSteps    = weekly.map(\.steps).reduce(0, +)
        let totalCalories = weekly.map(\.calories).reduce(0, +)
        let totalDistKm   = weekly.map(\.distanceKm).reduce(0, +)
        let activeDays    = weekly.filter { $0.steps >= 8_000 }.count
        let maxSteps      = max(weekly.map(\.steps).max() ?? 1, 1)

        let stepChart = padded(weekly.map { CGFloat($0.steps) / CGFloat(maxSteps) })
        let calChart  = padded(weekly.map { CGFloat($0.calories) / CGFloat(max(weekly.map(\.calories).max() ?? 1, 1)) })
        let distChart = padded(weekly.map { CGFloat($0.distanceKm) / CGFloat(max(weekly.map(\.distanceKm).max() ?? 0.001, 0.001)) })
        let trendChart = stepChart.enumerated().map { i, v in min(v + CGFloat(i) * 0.015, 1.0) }

        // Heart
        let heartDesc: String
        if let hr = heartRate {
            let zone = hr < 60 ? "excellent" : hr < 70 ? "great" : hr < 80 ? "normal" : "slightly elevated"
            heartDesc = "Your latest heart rate is \(hr) BPM (\(zone)). Walking \(activeDays)/7 days this week actively strengthens your cardiovascular system."
        } else {
            heartDesc = "You were active \(activeDays) out of 7 days this week. Consistent walking lowers resting heart rate by 5–10 BPM over 3 months."
        }

        // Calories / Weight
        let calDesc = totalCalories > 0
            ? "You burned \(totalCalories.formatted()) calories walking this week — about \(totalCalories / 7) per day. At this pace you'll burn ~\((totalCalories * 4).formatted()) cal this month."
            : "Start walking to track your calorie burn. Every step burns roughly 0.04 kcal."

        // Distance / Sleep
        let distDesc = totalDistKm > 0
            ? String(format: "You covered %.1f km this week. Research shows walking 5+ km/day improves sleep quality by up to 25%%.", totalDistKm)
            : "Track your distance. Walking 5+ km daily is linked to significantly better sleep quality."

        // Activity Consistency / Mind
        let mindDesc: String
        switch activeDays {
        case 6...7: mindDesc = "Outstanding — \(activeDays)/7 active days! High consistency like yours reduces stress by up to 30% and sharpens focus."
        case 4...5: mindDesc = "Good week — \(activeDays)/7 active days. Reaching 6+ days will unlock the full mental wellness benefits of regular walking."
        case 1...3: mindDesc = "You walked \(activeDays) days this week. Even 3× per week boosts mood and reduces anxiety — keep building the habit."
        default:    mindDesc = "Walking just 20 minutes daily boosts creative thinking by 60% and reduces cortisol. Your first step is the most important one."
        }

        return [
            .heart:  InsightCard(category: .heart,  title: "Cardiovascular Activity",  description: heartDesc, projectionText: activeDays >= 5 ? "On track for strong heart health" : "Add \(5 - activeDays) more active days", chartData: stepChart),
            .weight: InsightCard(category: .weight, title: "Calorie Burn",             description: calDesc,   projectionText: totalCalories > 0 ? "~\((totalCalories * 4).formatted()) cal projected this month" : "Start walking to see projections", chartData: calChart),
            .sleep:  InsightCard(category: .sleep,  title: "Distance & Recovery",      description: distDesc,  projectionText: String(format: "%.1f km projected this month", totalDistKm * 4.0), chartData: distChart),
            .mind:   InsightCard(category: .mind,   title: "Activity Consistency",     description: mindDesc,  projectionText: activeDays >= 6 ? "Excellent mental wellness trend" : "Aim for \(max(5 - activeDays, 1)) more active days", chartData: trendChart),
        ]
    }

    private func generateWeeklySummary(weekly: [DailyStats], prevWeek: [DailyStats]) -> WeeklySummary {
        let total     = weekly.map(\.steps).reduce(0, +)
        let prevTotal = prevWeek.map(\.steps).reduce(0, +)
        let change    = prevTotal > 0 ? Int(((Double(total) - Double(prevTotal)) / Double(prevTotal)) * 100) : 0
        let note      = total > 0
            ? "Your most active window this week. Try scheduling walks here for maximum benefit."
            : "Complete some walks to discover your personal peak activity hours."
        return WeeklySummary(totalSteps: total, percentChangeVsPrevious: change, peakHoursStart: "9:00", peakHoursEnd: "10:30 AM", peakHoursNote: note)
    }

    private func generateRecommendations(weekly: [DailyStats], heartRate: Int?) -> [CoachRecommendation] {
        let totalSteps = weekly.map(\.steps).reduce(0, +)
        let avgSteps   = totalSteps / max(weekly.count, 1)
        let activeDays = weekly.filter { $0.steps >= 8_000 }.count

        var recs: [CoachRecommendation] = []

        if let hr = heartRate, hr > 75 {
            recs.append(CoachRecommendation(
                icon: "heart.fill", iconColor: .iwSecondary, backgroundColor: .iwSecondaryFixed,
                title: "Lower Resting Heart Rate",
                description: "Your heart rate is \(hr) BPM. Brisk daily walks can lower this by 5–10 BPM over 3 months.",
                detailedInfo: "Walk at 100+ steps/min for 30 minutes daily. A resting HR of 60–70 BPM is the target. Your current \(hr) BPM is very achievable with consistency."
            ))
        }

        if activeDays < 5 {
            recs.append(CoachRecommendation(
                icon: "calendar.badge.checkmark", iconColor: .iwPrimary, backgroundColor: .iwPrimaryFixed.opacity(0.3),
                title: "Build a 5-Day Habit",
                description: "You walked actively \(activeDays)/7 days. Walking 5 days per week is the minimum for lasting health benefits.",
                detailedInfo: "Research shows 21 days of consistent action forms a lasting habit. Try setting a daily reminder at the same time each day — even a 10-minute walk counts."
            ))
        }

        if avgSteps > 0 && avgSteps < 8_000 {
            recs.append(CoachRecommendation(
                icon: "figure.walk", iconColor: .iwTertiary, backgroundColor: .iwTertiaryFixed,
                title: "Close the 8k Gap",
                description: "Your average is \(avgSteps.formatted()) steps/day. Just \((8_000 - avgSteps).formatted()) more steps reaches the health baseline.",
                detailedInfo: "8,000 steps/day reduces all-cause mortality risk by up to 51%. One extra 15-minute walk daily is typically all it takes to close this gap."
            ))
        }

        if recs.isEmpty {
            recs.append(CoachRecommendation(
                icon: "sun.max.fill", iconColor: .iwTertiary, backgroundColor: .iwTertiaryFixed,
                title: "Excellent Week!",
                description: "You're hitting your targets consistently. Add interval walking to boost calorie burn by 40%.",
                detailedInfo: "Alternate between brisk (2 min) and moderate (1 min) paces. This variation increases calorie burn, improves cardiovascular fitness faster, and keeps walks mentally engaging."
            ))
        }

        return Array(recs.prefix(2))
    }

    private func generateWeeklyReport(weekly: [DailyStats], prevWeek: [DailyStats], heartRate: Int?) -> WeeklyReport {
        let totalSteps    = weekly.map(\.steps).reduce(0, +)
        let totalCalories = weekly.map(\.calories).reduce(0, +)
        let totalDistKm   = weekly.map(\.distanceKm).reduce(0, +)
        let activeDays    = weekly.filter { $0.steps >= 8_000 }.count
        let bestDay       = weekly.max(by: { $0.steps < $1.steps })
        let prevTotal     = prevWeek.map(\.steps).reduce(0, +)
        let change        = prevTotal > 0 ? Int(((Double(totalSteps) - Double(prevTotal)) / Double(prevTotal)) * 100) : 0

        return WeeklyReport(
            totalSteps: totalSteps, totalCalories: totalCalories, totalDistanceKm: totalDistKm,
            activeDays: activeDays, bestDaySteps: bestDay?.steps ?? 0, bestDayName: bestDay?.shortDayName ?? "--",
            weekOverWeekChange: change, heartRate: heartRate
        )
    }

    // MARK: - Helpers

    private func padded(_ data: [CGFloat], count: Int = 20) -> [CGFloat] {
        guard !data.isEmpty else { return Array(repeating: 0.3, count: count) }
        if data.count >= count { return Array(data.prefix(count)) }
        var result = data
        while result.count < count { result.insert(data.first ?? 0.3, at: 0) }
        return result
    }

    func toggleCoachRecommendation(_ recommendation: CoachRecommendation) {
        withAnimation(.easeInOut(duration: 0.25)) {
            expandedCoachRecommendationId = expandedCoachRecommendationId == recommendation.id ? nil : recommendation.id
        }
    }

    func selectCategory(_ category: MetricCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            chartAnimated = false
            cardsVisible  = false
            selectedCategory = category
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.6)) {
                self.chartAnimated = true
                self.cardsVisible  = true
            }
        }
    }

    func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                self.chartAnimated = true
                self.cardsVisible  = true
            }
        }
    }
}
