import Foundation
import CoreLocation
import SwiftUI

// MARK: - Walk Session

enum WalkPhase: Equatable {
    case countdown(Int) // 3, 2, 1, 0 (Go!)
    case active
    case paused
    case summary(WalkSession)

    static func == (lhs: WalkPhase, rhs: WalkPhase) -> Bool {
        switch (lhs, rhs) {
        case (.countdown(let a), .countdown(let b)): a == b
        case (.active, .active): true
        case (.paused, .paused): true
        case (.summary, .summary): true
        default: false
        }
    }
}

enum WalkMilestone: CaseIterable {
    case quarter, half, threeQuarter, complete

    var threshold: Double {
        switch self {
        case .quarter: 0.25
        case .half: 0.50
        case .threeQuarter: 0.75
        case .complete: 1.0
        }
    }

    var title: String {
        switch self {
        case .quarter: "25% There!"
        case .half: "Halfway!"
        case .threeQuarter: "Almost There!"
        case .complete: "Goal Crushed!"
        }
    }

    var icon: String {
        switch self {
        case .quarter: "flame.fill"
        case .half: "star.fill"
        case .threeQuarter: "bolt.fill"
        case .complete: "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .quarter: .iwTertiaryContainer
        case .half: .iwSecondary
        case .threeQuarter: .iwPrimaryContainer
        case .complete: .iwPrimaryFixed
        }
    }
}

struct WalkSession: Codable, Equatable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    var steps: Int
    var calories: Int
    var distanceKm: Double
    var elapsedSeconds: Int
    let dailyGoal: Int
    let stepsBeforeWalk: Int
    var averageHeartRate: Int
    var routePoints: [WalkRoutePoint]?

    var totalSteps: Int { stepsBeforeWalk + steps }
    var goalProgressBefore: Double { min(Double(stepsBeforeWalk) / Double(dailyGoal), 1.0) }
    var goalProgressAfter: Double { min(Double(totalSteps) / Double(dailyGoal), 1.0) }

    var paceMinPerKm: Double {
        guard distanceKm > 0.01 else { return 0 }
        return (Double(elapsedSeconds) / 60.0) / distanceKm
    }

    var formattedDuration: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    var elapsedFormatted: String {
        let mins = elapsedSeconds / 60
        let secs = elapsedSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var paceFormatted: String {
        guard paceMinPerKm > 0 && paceMinPerKm < 100 else { return "--:--" }
        let mins = Int(paceMinPerKm)
        let secs = Int((paceMinPerKm - Double(mins)) * 60)
        return String(format: "%d:%02d", mins, secs)
    }

    var highestMilestone: WalkMilestone? {
        WalkMilestone.allCases.last { goalProgressAfter >= $0.threshold }
    }

    static func == (lhs: WalkSession, rhs: WalkSession) -> Bool { lhs.id == rhs.id }
}

struct WalkRoutePoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - User

struct UserProfile {
    var name: String
    var dailyStepGoal: Int
    var avatarSystemName: String

    static let mock = UserProfile(
        name: "Sarah",
        dailyStepGoal: 10_000,
        avatarSystemName: "person.fill"
    )
}

// MARK: - Daily Stats

struct DailyStats: Identifiable {
    let id = UUID()
    var date: Date
    var steps: Int
    var calories: Int
    var distanceKm: Double
    var activeMinutes: Int
    var heartRate: Int?

    static let mockToday = DailyStats(
        date: .now,
        steps: 8_500,
        calories: 420,
        distanceKm: 5.8,
        activeMinutes: 45,
        heartRate: 72
    )

    static let mockWeek: [DailyStats] = {
        let calendar = Calendar.current
        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -6 + daysAgo, to: .now) ?? .now
            let steps = [4200, 6800, 9100, 5400, 11200, 7800, 8500][daysAgo]
            return DailyStats(
                date: date,
                steps: steps,
                calories: steps / 20,
                distanceKm: Double(steps) / 1400.0,
                activeMinutes: steps / 200,
                heartRate: Int.random(in: 65...80)
            )
        }
    }()

    var shortDayName: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }
}

// MARK: - Health Tip

struct HealthTip: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let content: String

    static let mockTips: [HealthTip] = [
        HealthTip(icon: "lightbulb.fill", title: "Health Tip", content: "Walking after lunch can lower your blood sugar by 12%."),
        HealthTip(icon: "heart.fill", title: "Heart Health", content: "30 minutes of brisk walking daily reduces heart disease risk by 35%."),
        HealthTip(icon: "moon.stars.fill", title: "Sleep Better", content: "Evening walks can improve sleep quality by up to 25%."),
        HealthTip(icon: "brain.head.profile", title: "Mental Boost", content: "A 20-minute walk can boost creative thinking by 60%."),
        HealthTip(icon: "lungs.fill", title: "Breathe Easy", content: "Regular walking increases lung capacity by up to 15% over 6 months."),
    ]
}

// MARK: - Health Metric (for AI Insights)

enum MetricCategory: String, CaseIterable, Identifiable {
    case heart = "Heart"
    case weight = "Weight"
    case sleep = "Sleep"
    case mind = "Mind"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .heart: "heart.fill"
        case .weight: "scalemass.fill"
        case .sleep: "moon.zzz.fill"
        case .mind: "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .heart: .iwError
        case .weight: .iwTertiary
        case .sleep: .iwSecondary
        case .mind: .iwPrimary
        }
    }
}

struct InsightCard: Identifiable {
    let id = UUID()
    let category: MetricCategory
    let title: String
    let description: String
    let projectionText: String
    let chartData: [CGFloat]

    static let mockInsights: [MetricCategory: InsightCard] = [
        .heart: InsightCard(
            category: .heart,
            title: "Cardiovascular Health",
            description: "Your resting heart rate has improved by 8% since you started walking regularly.",
            projectionText: "15% improvement in 3 months",
            chartData: [0.4, 0.5, 0.3, 0.6, 0.8, 1.0, 0.7, 0.5, 0.4, 0.6, 0.5, 0.7, 0.9, 0.6, 0.4, 0.5, 0.3, 0.6, 0.7, 0.5]
        ),
        .weight: InsightCard(
            category: .weight,
            title: "Weight Management",
            description: "You've burned 12,400 calories this month through walking alone. Consistent pace!",
            projectionText: "On track to lose 1.5 kg this month",
            chartData: [0.9, 0.85, 0.82, 0.8, 0.78, 0.76, 0.75, 0.73, 0.72, 0.7, 0.68, 0.67, 0.66, 0.65, 0.63, 0.62, 0.6, 0.59, 0.58, 0.57]
        ),
        .sleep: InsightCard(
            category: .sleep,
            title: "Sleep Quality",
            description: "On days you walk 8,000+ steps, your deep sleep increases by 22 minutes on average.",
            projectionText: "Sleep score trending up 18%",
            chartData: [0.5, 0.6, 0.4, 0.7, 0.8, 0.6, 0.9, 0.7, 0.8, 0.85, 0.7, 0.9, 0.75, 0.8, 0.85, 0.9, 0.8, 0.85, 0.9, 0.95]
        ),
        .mind: InsightCard(
            category: .mind,
            title: "Mental Wellness",
            description: "Your stress indicators drop by 30% on days with morning walks. Keep it up!",
            projectionText: "Mood score up 24% this quarter",
            chartData: [0.3, 0.4, 0.5, 0.45, 0.6, 0.55, 0.7, 0.65, 0.75, 0.7, 0.8, 0.75, 0.85, 0.8, 0.9, 0.85, 0.88, 0.9, 0.92, 0.95]
        ),
    ]
}

struct WeeklySummary {
    let totalSteps: Int
    let percentChangeVsPrevious: Int
    let peakHoursStart: String
    let peakHoursEnd: String
    let peakHoursNote: String

    static let mock = WeeklySummary(
        totalSteps: 45_000,
        percentChangeVsPrevious: 12,
        peakHoursStart: "10:00",
        peakHoursEnd: "11:30 AM",
        peakHoursNote: "You burn the most calories during this window. Try scheduling walks here."
    )
}

struct RecommendedFocus: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String

    static let mockByCategory: [MetricCategory: RecommendedFocus] = [
        .heart: RecommendedFocus(icon: "waveform.path.ecg", title: "Increase Evening Walks", description: "Your data shows 30% better sleep quality on days with evening activity."),
        .weight: RecommendedFocus(icon: "flame.fill", title: "Add Interval Walking", description: "Alternating pace burns 40% more calories than steady walking."),
        .sleep: RecommendedFocus(icon: "bed.double.fill", title: "Walk Before 7 PM", description: "Late walks within 2 hours of bed may reduce sleep quality."),
        .mind: RecommendedFocus(icon: "leaf.fill", title: "Nature Walks", description: "Green spaces reduce cortisol levels 15% more than urban routes."),
    ]
}

// MARK: - Badge

struct Badge: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let description: String
    let requirement: String
    var isUnlocked: Bool
    var unlockedDate: Date?
    var progress: Double // 0.0 to 1.0

    static let mockBadges: [Badge] = [
        Badge(name: "Early Bird", icon: "sunrise.fill", color: .iwTertiaryContainer, description: "Complete a walk before 7 AM", requirement: "Walk before 7:00 AM", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -30, to: .now), progress: 1.0),
        Badge(name: "Routine Runner", icon: "figure.run", color: .iwPrimaryContainer, description: "Walk every day for a week", requirement: "7 consecutive days", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -14, to: .now), progress: 1.0),
        Badge(name: "Forever 10,247", icon: "infinity", color: .iwSecondaryFixedDim, description: "Reach exactly 10,247 steps in one day", requirement: "Exactly 10,247 steps", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -7, to: .now), progress: 1.0),
        Badge(name: "10k Club", icon: "star.fill", color: .iwPrimaryFixed, description: "Hit 10,000 steps in a single day", requirement: "10,000 steps in one day", isUnlocked: true, unlockedDate: Calendar.current.date(byAdding: .day, value: -21, to: .now), progress: 1.0),
        Badge(name: "Half Marathon", icon: "medal.fill", color: .iwTertiaryFixedDim, description: "Walk 21.1 km in a single day", requirement: "21.1 km total distance", isUnlocked: false, progress: 0.72),
        Badge(name: "Night Owl", icon: "moon.stars.fill", color: .iwInverseSurface, description: "Complete a walk after 10 PM", requirement: "Walk after 10:00 PM", isUnlocked: false, progress: 0.0),
    ]
}

// MARK: - Challenge

struct Challenge: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let iconColor: Color
    let goalValue: Int
    var currentValue: Int
    let unit: String
    let deadline: Date?
    var isJoined: Bool

    var progress: Double {
        min(Double(currentValue) / Double(goalValue), 1.0)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    static let mockChallenges: [Challenge] = [
        Challenge(
            name: "Weekend 30k",
            description: "Walk or run 30,000 steps between Friday and Sunday to earn the Explorer medal.",
            icon: "figure.walk",
            iconColor: .iwPrimary,
            goalValue: 30_000,
            currentValue: 19_200,
            unit: "steps",
            deadline: Calendar.current.date(byAdding: .day, value: 2, to: .now),
            isJoined: true
        ),
        Challenge(
            name: "Hydration Master",
            description: "Drink 8 glasses of water a day for 7 days straight.",
            icon: "drop.fill",
            iconColor: .iwSecondary,
            goalValue: 7,
            currentValue: 5,
            unit: "days",
            deadline: Calendar.current.date(byAdding: .day, value: 5, to: .now),
            isJoined: true
        ),
        Challenge(
            name: "Sunrise Streak",
            description: "Complete a morning walk before 8 AM for 5 consecutive days.",
            icon: "sunrise.fill",
            iconColor: .iwTertiary,
            goalValue: 5,
            currentValue: 2,
            unit: "days",
            deadline: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            isJoined: false
        ),
    ]
}

// MARK: - Leaderboard

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let steps: Int
    let isCurrentUser: Bool

    static let mockEntries: [LeaderboardEntry] = [
        LeaderboardEntry(rank: 1, name: "Alex M.", steps: 98_450, isCurrentUser: false),
        LeaderboardEntry(rank: 2, name: "Jordan K.", steps: 87_200, isCurrentUser: false),
        LeaderboardEntry(rank: 3, name: "Taylor S.", steps: 82_100, isCurrentUser: false),
        LeaderboardEntry(rank: 4, name: "Morgan W.", steps: 76_800, isCurrentUser: false),
        LeaderboardEntry(rank: 5, name: "Casey R.", steps: 71_500, isCurrentUser: false),
        LeaderboardEntry(rank: 1240, name: "Sarah", steps: 45_000, isCurrentUser: true),
    ]
}

// MARK: - Habit

enum HabitCompletion: Int {
    case none = 0
    case partial = 1
    case complete = 2
}

struct HabitDay: Identifiable {
    let id = UUID()
    let date: Date
    let completion: HabitCompletion
    let steps: Int

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }
}

struct MonthlyHabitData {
    let year: Int
    let month: Int
    let days: [HabitDay]

    var completedDays: Int {
        days.filter { $0.completion == .complete }.count
    }

    var completionRate: Double {
        guard !days.isEmpty else { return 0 }
        return Double(completedDays) / Double(days.count)
    }

    var averageSteps: Int {
        guard !days.isEmpty else { return 0 }
        return days.map(\.steps).reduce(0, +) / days.count
    }

    var firstWeekdayOffset: Int {
        let calendar = Calendar.current
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 0 }
        return (calendar.component(.weekday, from: firstDay) - 1) // Sunday = 0
    }

    var daysInMonth: Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = calendar.date(from: dateComponents),
              let range = calendar.range(of: .day, in: .month, for: date) else { return 30 }
        return range.count
    }

    var monthYearString: String {
        let dateComponents = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: dateComponents) else { return "" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    static func mock(year: Int, month: Int) -> MonthlyHabitData {
        let calendar = Calendar.current
        let refDate = calendar.date(from: DateComponents(year: year, month: month)) ?? .now
        let daysCount = calendar.range(of: .day, in: .month, for: refDate)?.count ?? 30

        let days = (1...daysCount).map { day -> HabitDay in
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
            let isToday = calendar.isDateInToday(date)
            let isFuture = date > .now

            if isFuture {
                return HabitDay(date: date, completion: .none, steps: 0)
            }

            let rand = Double.random(in: 0...1)
            let completion: HabitCompletion = rand > 0.3 ? .complete : (rand > 0.1 ? .partial : .none)
            let steps = completion == .complete ? Int.random(in: 8000...15000) :
                        completion == .partial ? Int.random(in: 3000...7999) :
                        Int.random(in: 500...2999)

            return HabitDay(date: date, completion: isToday ? .partial : completion, steps: steps)
        }

        return MonthlyHabitData(year: year, month: month, days: days)
    }
}

struct PersonalRecord {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    static let mockRecords: [PersonalRecord] = [
        PersonalRecord(title: "Longest Streak", value: "14 Days", icon: "flame.fill", iconColor: .iwTertiaryContainer),
        PersonalRecord(title: "Most Steps", value: "18,420", icon: "figure.walk", iconColor: .iwPrimaryContainer),
    ]
}

// MARK: - AI Coach

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct CoachMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }

    static func userMessage(_ content: String) -> CoachMessage {
        CoachMessage(role: .user, content: content, timestamp: .now)
    }

    static func assistantMessage(_ content: String) -> CoachMessage {
        CoachMessage(role: .assistant, content: content, timestamp: .now)
    }
}

struct CoachRecommendation: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let backgroundColor: Color
    let title: String
    let description: String
    let detailedInfo: String

    static let mockRecommendations: [CoachRecommendation] = [
        CoachRecommendation(
            icon: "sun.max.fill",
            iconColor: .iwTertiary,
            backgroundColor: .iwTertiaryFixed,
            title: "Vitamin D Boost!",
            description: "Try a morning walk of 15-20 minutes outdoors. Your vitamin D intake has been low this week.",
            detailedInfo: "Vitamin D is essential for bone health, immune function, and mood regulation. Morning sunlight exposure between 8-10 AM provides the most efficient vitamin D synthesis. Aim for 15-20 minutes of direct sunlight on your arms and face."
        ),
        CoachRecommendation(
            icon: "heart.fill",
            iconColor: .iwSecondary,
            backgroundColor: .iwSecondaryFixed,
            title: "Beat Better!",
            description: "Your BPM is slightly elevated. Consider a brisk walk to help regulate cardiovascular rhythm.",
            detailedInfo: "Regular brisk walking has been shown to lower resting heart rate by 5-10 BPM over 3 months. Your current resting heart rate of 78 BPM could benefit from 30-minute walks at 100-110 steps per minute."
        ),
    ]
}

struct CoachSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let aiResponse: String

    static let mockSuggestions: [CoachSuggestion] = [
        CoachSuggestion(
            text: "Did you know that a brisk 30-minute walk...",
            aiResponse: "A brisk 30-minute walk burns approximately 150-200 calories and can boost your metabolism for up to 2 hours afterward. It also releases endorphins, which naturally elevate your mood. Studies show that consistent daily walks reduce the risk of chronic diseases by up to 40%."
        ),
        CoachSuggestion(
            text: "What are the best stretches before walking?",
            aiResponse: "Before walking, focus on dynamic stretches: leg swings (10 each side), hip circles (10 each direction), ankle rolls (10 each), and calf raises (15 reps). These warm up your joints and muscles without reducing power output. Save static stretches for after your walk."
        ),
        CoachSuggestion(
            text: "How can I improve my walking posture?",
            aiResponse: "Great posture starts from the top: keep your chin parallel to the ground, shoulders relaxed and back, arms at 90° swinging naturally, core gently engaged, and land on your heel rolling to your toe. Imagine a string pulling you up from the crown of your head."
        ),
    ]
}

// MARK: - Weekly Health Report

struct WeeklyReport {
    let totalSteps: Int
    let totalCalories: Int
    let totalDistanceKm: Double
    let activeDays: Int
    let bestDaySteps: Int
    let bestDayName: String
    let weekOverWeekChange: Int
    let heartRate: Int?

    var grade: String {
        switch activeDays {
        case 6...7: return "Excellent"
        case 4...5: return "Good"
        case 2...3: return "Getting There"
        default:    return "Just Starting"
        }
    }

    var gradeColor: Color {
        switch activeDays {
        case 6...7: return .iwPrimary
        case 4...5: return .iwSecondary
        case 2...3: return .iwTertiary
        default:    return .iwOutline
        }
    }

    var changeLabel: String {
        weekOverWeekChange >= 0 ? "+\(weekOverWeekChange)%" : "\(weekOverWeekChange)%"
    }
}

// MARK: - Leaderboard Sync

enum LeaderboardSyncSource {
    case local
    case cloudKit
}

// MARK: - Inspirational Quote

struct InspirationalQuote: Identifiable {
    let id = UUID()
    let text: String
    let author: String

    static let quotes: [InspirationalQuote] = [
        InspirationalQuote(text: "Success is the sum of small efforts, repeated day in and day out.", author: "Robert Collier"),
        InspirationalQuote(text: "An early-morning walk is a blessing for the whole day.", author: "Henry David Thoreau"),
        InspirationalQuote(text: "Walking is man's best medicine.", author: "Hippocrates"),
        InspirationalQuote(text: "All truly great thoughts are conceived while walking.", author: "Friedrich Nietzsche"),
        InspirationalQuote(text: "The journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
    ]
}
