import Foundation

enum HealthDataPresence {
    static func hasDashboardRealData(
        steps: Int,
        distanceKm: Double,
        calories: Int,
        weeklyCount: Int
    ) -> Bool {
        steps > 0 || distanceKm > 0 || calories > 0 || weeklyCount > 0
    }

    static func hasCoachRealData(
        steps: Int,
        weeklyCount: Int,
        heartRate: Int?
    ) -> Bool {
        steps > 0 || weeklyCount > 0 || heartRate != nil
    }

    static func hasInsightsRealData(
        weeklyCount: Int,
        heartRate: Int?
    ) -> Bool {
        weeklyCount > 0 || heartRate != nil
    }

    static func hasBadgeComparisonRealData(
        todaySteps: Int,
        thisWeekCount: Int,
        prevWeekCount: Int
    ) -> Bool {
        todaySteps > 0 || thisWeekCount > 0 || prevWeekCount > 0
    }

    static func hasHabitRealData(monthCount: Int) -> Bool {
        monthCount > 0
    }
}
