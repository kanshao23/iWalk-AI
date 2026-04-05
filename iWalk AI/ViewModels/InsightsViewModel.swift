import SwiftUI

@Observable
final class InsightsViewModel {
    var selectedCategory: MetricCategory = .heart
    var insights = InsightCard.mockInsights
    var weeklySummary = WeeklySummary.mock
    var recommendedFocus = RecommendedFocus.mockByCategory

    // Animation states
    var chartAnimated = false
    var cardsVisible = false

    var currentInsight: InsightCard? {
        insights[selectedCategory]
    }

    var currentFocus: RecommendedFocus? {
        recommendedFocus[selectedCategory]
    }

    func selectCategory(_ category: MetricCategory) {
        withAnimation(.easeInOut(duration: 0.3)) {
            chartAnimated = false
            cardsVisible = false
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedCategory = category
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.6)) {
                self.chartAnimated = true
                self.cardsVisible = true
            }
        }
    }

    func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                self.chartAnimated = true
                self.cardsVisible = true
            }
        }
    }
}
