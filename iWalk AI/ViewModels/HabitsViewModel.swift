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

    init() {
        let now = Date.now
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        self.currentYear = year
        self.currentMonth = month
        self.monthData = MonthlyHabitData.mock(year: year, month: month)
    }

    func goToPreviousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentMonth == 1 {
                currentMonth = 12
                currentYear -= 1
            } else {
                currentMonth -= 1
            }
            monthData = MonthlyHabitData.mock(year: currentYear, month: currentMonth)
        }
    }

    func goToNextMonth() {
        let now = Date.now
        let calendar = Calendar.current
        let nowYear = calendar.component(.year, from: now)
        let nowMonth = calendar.component(.month, from: now)

        // Don't go beyond current month
        if currentYear == nowYear && currentMonth >= nowMonth { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            if currentMonth == 12 {
                currentMonth = 1
                currentYear += 1
            } else {
                currentMonth += 1
            }
            monthData = MonthlyHabitData.mock(year: currentYear, month: currentMonth)
        }
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
