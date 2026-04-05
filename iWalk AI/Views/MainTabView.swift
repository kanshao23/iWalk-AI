import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .daily

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .daily:
                    DashboardView()
                case .insights:
                    AIInsightsView()
                case .coach:
                    AICoachView()
                case .habits:
                    HabitsView()
                case .badges:
                    BadgesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)

            GlassTabBar(selectedTab: $selectedTab)
        }
        .background(Color.iwSurface)
        .ignoresSafeArea(edges: .bottom)
    }
}
