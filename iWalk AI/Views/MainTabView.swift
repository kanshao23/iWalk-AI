import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: TabItem = .daily
    @State private var storeKit = StoreKitManager.shared
    @State private var openActiveWalk = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .daily:
                    DashboardView(openActiveWalk: $openActiveWalk)
                case .insights:
                    if storeKit.isPremium {
                        AIInsightsView()
                    } else {
                        ProGateView(
                            featureIcon: "brain.head.profile",
                            featureName: "AI Insights",
                            featureDescription: "Unlock personalized health analysis, deep trends, and weekly wellness reports powered by AI."
                        )
                    }
                case .coach:
                    if storeKit.isPremium {
                        AICoachView()
                    } else {
                        ProGateView(
                            featureIcon: "person.fill.questionmark",
                            featureName: "AI Coach",
                            featureDescription: "Get real-time coaching that adapts to your pace, streak, and daily goals — powered by AI."
                        )
                    }
                case .habits:
                    HabitsView()
                case .badges:
                    BadgesView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)

            GlassTabBar(selectedTab: $selectedTab, isPremium: storeKit.isPremium)
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
        .onOpenURL { url in
            guard let route = AppDeepLinkRouter.route(for: url) else { return }
            switch route {
            case .home:
                selectedTab = .daily
                openActiveWalk = false
            case .activeWalk:
                selectedTab = .daily
                openActiveWalk = true
            case .pauseWalk:
                NotificationCenter.default.post(name: .iwPauseResumeWalk, object: nil)
            case .endWalk:
                NotificationCenter.default.post(name: .iwEndWalk, object: nil)
            }
        }
    }
}
