import SwiftUI

@MainActor
@Observable
final class CoachViewModel {
    var user = UserProfile.mock
    var messages: [CoachMessage] = []
    var recommendations: [CoachRecommendation] = []
    var suggestions = CoachSuggestion.mockSuggestions
    var inputText = ""
    var isTyping = false
    var expandedRecommendationId: UUID?
    var showChat = false
    var todaySteps: Int = DailyStats.mockToday.steps
    var weeklyActivity: [DailyStats] = DailyStats.mockWeek
    var latestHeartRate: Int?
    var hasRealActivityData = false
    private(set) var streak: StreakData = .mock

    private let healthKit = HealthKitManager.shared
    private let apiClient = CoachAPIClient()
    private let maxStoredMessages = 60
    private let messagesStorageKey = "iw_coach_messages_v1"
    private var pendingResponseCount = 0
    private var walkInsights: WalkInsightSummary?

    init() {
        loadMessages()
        refreshRecommendations()
        refreshDynamicSuggestions()
    }

    var analysisSubtitle: String {
        hasRealActivityData
        ? "Based on your latest activity data."
        : "Personalized from your goal and streak."
    }

    var goalSteps: Int { user.dailyStepGoal }

    var stepsRemaining: Int {
        max(goalSteps - todaySteps, 0)
    }

    var streakStepsRemaining: Int {
        max(1_500 - todaySteps, 0)
    }

    var weeklyAverageSteps: Int {
        let total = weeklyActivity.map(\.steps).reduce(0, +)
        return weeklyActivity.isEmpty ? 0 : total / weeklyActivity.count
    }

    var todaysFocus: String {
        if stepsRemaining == 0 {
            return "Goal complete. Add a short recovery walk to lock in consistency."
        }
        if streak.isAtRisk && streak.currentStreak > 0 {
            return "Protect your \(streak.currentStreak)-day streak and close \(stepsRemaining.formatted()) remaining steps."
        }
        return "Reach \(goalSteps.formatted()) steps today. \(stepsRemaining.formatted()) to go."
    }

    var focusDetail: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let window: String
        switch hour {
        case 5..<11: window = "morning window"
        case 11..<16: window = "post-lunch window"
        case 16..<20: window = "early-evening window"
        default: window = "next available 20-minute window"
        }

        if weeklyAverageSteps >= goalSteps {
            return "You're trending above your weekly target. Use the \(window) to keep momentum without overloading."
        }
        return "You're averaging \(weeklyAverageSteps.formatted()) steps this week. A focused walk in the \(window) can recover the gap."
    }

    func refreshContext(streak: StreakData) async {
        self.streak = streak

        async let fetchedSteps = healthKit.fetchTodaySteps()
        async let fetchedWeekly = healthKit.fetchWeeklySteps()
        async let fetchedHeartRate = healthKit.fetchLatestHeartRate()

        let steps = await fetchedSteps
        let weekly = await fetchedWeekly
        let heartRate = await fetchedHeartRate
        let shouldUseRealData = HealthDataPresence.hasCoachRealData(
            steps: steps,
            weeklyCount: weekly.count,
            heartRate: heartRate
        )
        guard shouldUseRealData else {
            todaySteps = DailyStats.mockToday.steps
            weeklyActivity = DailyStats.mockWeek
            latestHeartRate = nil
            hasRealActivityData = false
            refreshRecommendations()
            refreshDynamicSuggestions()
            return
        }

        todaySteps = steps
        latestHeartRate = heartRate
        weeklyActivity = weekly
        hasRealActivityData = todaySteps > 0 || !weekly.isEmpty || latestHeartRate != nil
        walkInsights = WalkInsightsEngine.analyze(history: ActiveWalkViewModel.loadHistory())
        refreshRecommendations()
        refreshDynamicSuggestions()
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = CoachMessage.userMessage(trimmed)
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(userMsg)
            showChat = true
        }
        inputText = ""
        persistMessages()
        enqueueAssistantResponse(for: trimmed)
    }

    private func enqueueAssistantResponse(for userText: String) {
        pendingResponseCount += 1
        isTyping = true

        Task {
            // Build message history for API (last 10 messages only)
            let apiHistory = messages.suffix(10).map { msg in
                CoachAPIClient.ChatMessage(
                    role: msg.role == .user ? "user" : "assistant",
                    content: msg.content
                )
            }

            let insights = walkInsights
            let context = CoachAPIClient.CoachContext(
                steps: todaySteps,
                streak: streak.currentStreak,
                goal: goalSteps,
                userName: user.name,
                totalWalks: insights?.totalWalks ?? 0,
                avgPaceMinPerKm: insights?.avgPaceMinPerKm ?? 0.0,
                bestTimeOfDay: insights?.bestTimeOfDay.rawValue ?? "unknown",
                paceTrend: insights?.paceTrend.rawValue ?? "stable",
                thisWeekWalks: insights?.weekComparison.thisWeekWalks ?? 0,
                lastWeekWalks: insights?.weekComparison.lastWeekWalks ?? 0
            )

            let reply: String
            do {
                reply = try await apiClient.sendMessage(history: apiHistory, context: context)
            } catch {
                // Graceful local fallback
                let fallback = generateResponse(for: userText)
                switch error {
                case CoachAPIError.invalidResponseStatus(let statusCode):
                    reply = "Coach is temporarily unavailable (status \(statusCode)), so here's a quick tip based on your latest activity. " + fallback
                case CoachAPIError.invalidPayload:
                    reply = "Coach returned an unexpected response, so here's a quick tip based on your latest activity. " + fallback
                case let urlError as URLError:
                    print("[CoachVM] URLError \(urlError.code.rawValue): \(urlError.localizedDescription)")
                    reply = "Network connection seems unstable, so here's a quick tip based on your latest activity. " + fallback
                default:
                    print("[CoachVM] Unhandled error: \(type(of: error)) | \(error)")
                    reply = fallback
                }
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                self.messages.append(CoachMessage.assistantMessage(reply))
            }
            self.pendingResponseCount = max(self.pendingResponseCount - 1, 0)
            self.isTyping = self.pendingResponseCount > 0
            self.persistMessages()
            self.refreshDynamicSuggestions()
        }
    }

    func sendSuggestion(_ suggestion: CoachSuggestion) {
        sendMessage(suggestion.text)
    }

    func toggleRecommendation(_ recommendation: CoachRecommendation) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedRecommendationId == recommendation.id {
                expandedRecommendationId = nil
            } else {
                expandedRecommendationId = recommendation.id
            }
        }
    }

    func generateStreakMessage(streak: StreakData) -> String? {
        if streak.isAtRisk && streak.currentStreak > 0 && streakStepsRemaining > 0 {
            return "Hey \(user.name)! \(streakStepsRemaining.formatted()) more steps keeps your \(streak.currentStreak)-day streak alive. A quick 15-minute walk should do it."
        }
        if StreakData.milestones.contains(streak.currentStreak) && streak.isActiveToday {
            return "Amazing! You've hit a \(streak.currentStreak)-day streak! That's real dedication. Your consistency is building lasting health habits."
        }
        if streak.currentStreak == 1 && streak.longestStreak > 1 {
            return "Welcome back! Every streak starts with day one. You've done \(streak.longestStreak) days before — you can do it again!"
        }
        return nil
    }

    private func generateResponse(for input: String) -> String {
        let lowered = input.lowercased()
        if lowered.contains("step") || lowered.contains("walk") {
            if stepsRemaining == 0 {
                return "You're already at \(todaySteps.formatted()) steps today, above your \(goalSteps.formatted()) target. Keep it light with a recovery walk and mobility work."
            }
            let minutesNeeded = max(Int(ceil(Double(stepsRemaining) / 110.0)), 10)
            return "You're at \(todaySteps.formatted()) of \(goalSteps.formatted()) steps. A brisk \(minutesNeeded)-minute walk should close most of the \(stepsRemaining.formatted())-step gap."
        } else if lowered.contains("calorie") || lowered.contains("burn") || lowered.contains("weight") {
            let estimatedCalories = max(Int(Double(todaySteps) * 0.045), 0)
            return "Based on today's \(todaySteps.formatted()) steps, you've burned roughly \(estimatedCalories) active calories from walking. A 30-minute brisk walk typically adds 140-180 calories."
        } else if lowered.contains("heart") || lowered.contains("cardio") {
            if let latestHeartRate {
                return "Your latest recorded heart rate is \(latestHeartRate) BPM. Regular zone-2 walks (comfortable but brisk) are a practical way to improve cardio efficiency over time."
            }
            return "Regular walking strengthens your heart and improves circulation. A consistent 30-minute daily walk is enough to improve cardiovascular fitness for most people."
        } else if lowered.contains("sleep") {
            return "Walking, especially in the morning or early afternoon, can significantly improve sleep quality. Exposure to natural light during walks helps regulate your circadian rhythm. Avoid vigorous walking within 2 hours of bedtime."
        } else {
            return "That's a great question! Walking offers numerous health benefits including improved cardiovascular health, better mood, stronger bones, and enhanced creativity. Is there a specific aspect of walking you'd like to explore further?"
        }
    }

    private func refreshRecommendations() {
        let gap = stepsRemaining
        let streakGap = streakStepsRemaining
        var cards: [CoachRecommendation] = []

        if gap > 0 {
            cards.append(
                CoachRecommendation(
                    icon: "target",
                    iconColor: .iwPrimary,
                    backgroundColor: .iwPrimaryFixed,
                    title: "Close Today's Gap",
                    description: "\(gap.formatted()) steps left to hit your daily goal.",
                    detailedInfo: "Split the remaining steps into two short walks. A 12-minute walk after your next meal and one more in the evening is enough for most days."
                )
            )
        }

        if streak.isAtRisk && streak.currentStreak > 0 && streakGap > 0 {
            cards.append(
                CoachRecommendation(
                    icon: "flame.fill",
                    iconColor: .iwTertiary,
                    backgroundColor: .iwTertiaryFixed,
                    title: "Streak Protection",
                    description: "\(streakGap.formatted()) steps protects your \(streak.currentStreak)-day streak tonight.",
                    detailedInfo: "Your streak completion threshold is 1,500 steps. Prioritize this first, then decide whether to push for your full daily goal."
                )
            )
        }

        if weeklyAverageSteps < goalSteps {
            cards.append(
                CoachRecommendation(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .iwSecondary,
                    backgroundColor: .iwSecondaryFixed,
                    title: "Lift Weekly Average",
                    description: "You're averaging \(weeklyAverageSteps.formatted()) steps vs \(goalSteps.formatted()) target.",
                    detailedInfo: "Focus on consistency over intensity. Adding 1,200-1,500 steps on low-activity days will move your weekly trend faster than one very long session."
                )
            )
        } else if let latestHeartRate, latestHeartRate >= 78 {
            cards.append(
                CoachRecommendation(
                    icon: "heart.fill",
                    iconColor: .iwSecondary,
                    backgroundColor: .iwSecondaryFixed,
                    title: "Heart-rate Recovery Walk",
                    description: "Latest heart rate is \(latestHeartRate) BPM. A steady walk can help regulation.",
                    detailedInfo: "Use a conversational pace for 20-30 minutes. Keep breathing controlled and avoid sprint intervals when recovery is the priority."
                )
            )
        } else {
            cards.append(
                CoachRecommendation(
                    icon: "leaf.fill",
                    iconColor: .iwTertiaryContainer,
                    backgroundColor: .iwPrimaryContainer,
                    title: "Nature Reset",
                    description: "Take one outdoor walk today to reduce stress and improve focus.",
                    detailedInfo: "Green-space walks are linked with stronger stress reduction than indoor treadmill sessions. Even 15 minutes has measurable mental benefits."
                )
            )
        }

        recommendations = Array(cards.prefix(3))
    }

    func refreshDynamicSuggestions() {
        let hour = Calendar.current.component(.hour, from: .now)
        let progressPct = goalSteps > 0 ? Double(todaySteps) / Double(goalSteps) : 0
        var newSuggestions: [CoachSuggestion] = []

        // Suggestion 1: progress-based
        if progressPct >= 1.0 {
            newSuggestions.append(CoachSuggestion(text: "Goal reached! How do I keep momentum?", aiResponse: ""))
        } else if progressPct < 0.3 && hour >= 14 {
            newSuggestions.append(CoachSuggestion(text: "Go for a 20-minute walk now?", aiResponse: ""))
        } else {
            newSuggestions.append(CoachSuggestion(
                text: "\(stepsRemaining.formatted()) steps to go — how do I close it?", aiResponse: ""))
        }

        // Suggestion 2: streak-based
        if streak.currentStreak >= 7 {
            newSuggestions.append(CoachSuggestion(
                text: "\(streak.currentStreak)-day streak! How do I push further?", aiResponse: ""))
        } else if streak.isAtRisk && streak.currentStreak > 0 {
            newSuggestions.append(CoachSuggestion(
                text: "\(streakStepsRemaining.formatted()) steps left to save my streak", aiResponse: ""))
        } else {
            newSuggestions.append(CoachSuggestion(text: "How do I walk more efficiently?", aiResponse: ""))
        }

        // Suggestion 3: time-based
        switch hour {
        case 5..<10:
            newSuggestions.append(CoachSuggestion(text: "Benefits of morning walks?", aiResponse: ""))
        case 12..<14:
            newSuggestions.append(CoachSuggestion(text: "How long should I walk after lunch?", aiResponse: ""))
        case 20..<23:
            newSuggestions.append(CoachSuggestion(text: "Does walking before bed affect sleep?", aiResponse: ""))
        default:
            newSuggestions.append(CoachSuggestion(text: "How am I doing today?", aiResponse: ""))
        }

        suggestions = newSuggestions
    }

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: messagesStorageKey),
              let saved = try? JSONDecoder().decode([CoachMessage].self, from: data) else {
            return
        }
        messages = Array(saved.suffix(maxStoredMessages))
        showChat = !messages.isEmpty
    }

    private func persistMessages() {
        let trimmed = Array(messages.suffix(maxStoredMessages))
        if trimmed.count != messages.count {
            messages = trimmed
        }
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: messagesStorageKey)
    }
}
