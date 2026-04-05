import SwiftUI

@Observable
final class HabitsViewModel {
    var currentYear: Int
    var currentMonth: Int
    var monthData: MonthlyHabitData
    var personalRecords = PersonalRecord.mockRecords
    var quotes = InspirationalQuote.quotes
    var currentQuoteIndex = 0

    // UI States
    var selectedDay: HabitDay?
    var streakAnimated = false

    var currentStreak: Int { 7 }
    var longestStreak: Int { 14 }

    var currentQuote: InspirationalQuote {
        quotes[currentQuoteIndex % quotes.count]
    }

    private let healthKit = HealthKitManager.shared

    init() {
        let now = Date.now
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        self.currentYear = year
        self.currentMonth = month
        self.monthData = MonthlyHabitData.mock(year: year, month: month)
    }

    /// Load real monthly data from HealthKit
    func loadRealData() async {
        guard healthKit.isAuthorized else { return }
        let days = await healthKit.fetchMonthlySteps(year: currentYear, month: currentMonth)
        if !days.isEmpty {
            await MainActor.run {
                monthData = MonthlyHabitData(year: currentYear, month: currentMonth, days: days)
            }
        }
    }

    func goToPreviousMonth() {
        if currentMonth == 1 {
            currentMonth = 12
            currentYear -= 1
        } else {
            currentMonth -= 1
        }
        reloadMonth()
    }

    func goToNextMonth() {
        let now = Date.now
        let calendar = Calendar.current
        let nowYear = calendar.component(.year, from: now)
        let nowMonth = calendar.component(.month, from: now)

        if currentYear == nowYear && currentMonth >= nowMonth { return }

        if currentMonth == 12 {
            currentMonth = 1
            currentYear += 1
        } else {
            currentMonth += 1
        }
        reloadMonth()
    }

    private func reloadMonth() {
        // Start with mock, then try real data
        withAnimation(.easeInOut(duration: 0.3)) {
            monthData = MonthlyHabitData.mock(year: currentYear, month: currentMonth)
        }
        Task { await loadRealData() }
    }

    func selectDay(_ day: HabitDay) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedDay?.id == day.id {
                selectedDay = nil
            } else {
                selectedDay = day
            }
        }
    }

    func nextQuote() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count
        }
    }

    func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                self.streakAnimated = true
            }
        }
    }
}
