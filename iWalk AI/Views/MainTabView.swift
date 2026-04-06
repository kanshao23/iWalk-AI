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
        .overlay(alignment: .top) {
            if let toast = ToastQueue.shared.current {
                CoinToast(amount: toast.amount, source: toast.source)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.iwSurface)
        .ignoresSafeArea(edges: .bottom)
    }
}
