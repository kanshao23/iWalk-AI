import SwiftUI

@Observable
final class CoachViewModel {
    var user = UserProfile.mock
    var messages: [CoachMessage] = []
    var recommendations = CoachRecommendation.mockRecommendations
    var suggestions = CoachSuggestion.mockSuggestions
    var inputText = ""
    var isTyping = false
    var expandedRecommendationId: UUID?
    var showChat = false

    var todaysFocus: String {
        "Reach 8,500 steps to maintain your 4-day streak."
    }

    var focusDetail: String {
        "I'd recommend hitting this goal before evening. Hitting the post-lunch window will significantly improve your daily calorie burn."
    }

    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMsg = CoachMessage.userMessage(text)
        withAnimation(.easeInOut(duration: 0.2)) {
            messages.append(userMsg)
            showChat = true
        }
        inputText = ""

        // Find matching suggestion response or generate generic
        let matchedSuggestion = suggestions.first { text.contains($0.text.prefix(20)) }
        let response = matchedSuggestion?.aiResponse ?? generateResponse(for: text)

        // Simulate typing delay
        isTyping = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isTyping = false
            withAnimation(.easeInOut(duration: 0.3)) {
                self.messages.append(CoachMessage.assistantMessage(response))
            }
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
        if streak.isAtRisk {
            return "Hey \(user.name)! You still need about 1,500 steps to keep your \(streak.currentStreak)-day streak alive. A quick 15-minute walk should do it!"
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
            return "Walking is one of the most accessible forms of exercise. For your current fitness level, I recommend aiming for 8,000-10,000 steps daily. Try breaking it into 3 shorter walks throughout the day if a single long walk feels challenging."
        } else if lowered.contains("calorie") || lowered.contains("burn") || lowered.contains("weight") {
            return "At a brisk pace (100 steps/minute), you burn approximately 5 calories per minute. A 30-minute walk burns roughly 150 calories. Combined with a balanced diet, regular walking can support healthy weight management."
        } else if lowered.contains("heart") || lowered.contains("cardio") {
            return "Regular walking strengthens your heart and improves circulation. Studies show that walking 30 minutes daily reduces heart disease risk by up to 35%. Your resting heart rate typically decreases as your cardiovascular fitness improves."
        } else if lowered.contains("sleep") {
            return "Walking, especially in the morning or early afternoon, can significantly improve sleep quality. Exposure to natural light during walks helps regulate your circadian rhythm. Avoid vigorous walking within 2 hours of bedtime."
        } else {
            return "That's a great question! Walking offers numerous health benefits including improved cardiovascular health, better mood, stronger bones, and enhanced creativity. Is there a specific aspect of walking you'd like to explore further?"
        }
    }
}
