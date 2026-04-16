import SwiftUI

struct DashboardView: View {
    @Binding var openActiveWalk: Bool
    @State private var vm = DashboardViewModel()
    @Environment(\.coinVM) private var coinVM
    @Environment(\.streakVM) private var streakVM
    @Environment(\.journeyVM) private var journeyVM

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header with coin balance
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.iwPrimary)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                            Text("iWalk AI")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)
                        }
                        Spacer()
                        StreakBadgeView(streak: streakVM.streak)
                        CoinBalanceView(balance: coinVM.account.balance)
                    }

                    // Hero Card: Progress + Stats (always visible)
                    AnimatedCard(delay: 0.1) {
                        VStack(spacing: 0) {
                            TieredProgressBar(
                                currentSteps: vm.animatedSteps,
                                goalSteps: vm.stepGoal,
                                tiers: coinVM.todayTiers,
                                personalGoal: coinVM.personalGoal,
                                animatedProgress: vm.animatedProgress
                            )

                            Divider()
                                .padding(.horizontal, 16)

                            HStack(spacing: 0) {
                                StatCard(
                                    icon: "flame.fill",
                                    value: "\(vm.isCaloriesEstimated ? "~" : "")\(vm.todayStats.calories)",
                                    label: "kcal",
                                    iconColor: .iwTertiaryContainer
                                )
                                StatCard(
                                    icon: "mappin.and.ellipse",
                                    value: "\(vm.isDistanceEstimated ? "~" : "")\(String(format: "%.1f", vm.todayStats.distanceKm))",
                                    label: "km",
                                    iconColor: .iwSecondary
                                )
                                StatCard(
                                    icon: "clock.fill",
                                    value: "\(vm.todayStats.activeMinutes)",
                                    label: "mins",
                                    iconColor: .iwPrimaryContainer
                                )
                            }
                            .padding(.vertical, 12)
                        }
                        .background(Color.iwSurfaceContainerLowest)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    // Start Walking Button (always visible)
                    PillButton("Start Walking Now", icon: "figure.walk") {
                        vm.startWalking()
                    }

                    // Evening Review (only after 8 pm, when data is ready)
                    if vm.isEveningMode, let review = vm.eveningReview {
                        AnimatedCard(delay: 0.0) {
                            EveningReviewCard(review: review) {
                                vm.claimReviewCoins(coinVM: coinVM)
                                vm.showEveningDetails = true
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.4), value: vm.isEveningMode)
                    }

                    // This Week's Activity
                    AnimatedCard(delay: 0.2) {
                        VStack(spacing: 16) {
                            SectionHeader("This Week", trailing: "View History") {
                                vm.showHistory = true
                            }
                            ActivityBarChart(
                                data: vm.chartData,
                                labels: vm.chartLabels,
                                accentIndex: vm.todayWeekdayIndex
                            )
                            .frame(height: 100)
                        }
                    }

                    // Journey Card (long-term goal, after weekly context)
                    if let journey = journeyVM.activeJourney {
                        AnimatedCard(delay: 0.3) {
                            JourneyCard(journey: journey)
                                .contentShape(Rectangle())
                                .onTapGesture { vm.showJourneyDetail = true }
                        }
                    }

                    // Health Tip
                    AnimatedCard(delay: 0.4) {
                        InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: vm.currentTip.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.iwTertiary)
                                    .padding(8)
                                    .background(Color.iwTertiaryFixed.opacity(0.4))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vm.currentTip.title)
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                    Text(vm.currentTip.content)
                                        .font(IWFont.bodyMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { vm.nextTip() }

                        HStack(spacing: 6) {
                            ForEach(0..<vm.healthTips.count, id: \.self) { i in
                                Circle()
                                    .fill(i == vm.currentTipIndex ? Color.iwPrimary : Color.iwOutlineVariant)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color.iwSurface)

            // Coin Toast overlay
            if coinVM.showCoinToast {
                CoinToast(amount: coinVM.lastEarnedAmount, source: coinVM.lastEarnedSource)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .onAppear {
            vm.animateOnAppear()
            coinVM.checkStepTiers(currentSteps: vm.currentSteps)
            if vm.currentSteps >= 1500 {
                streakVM.completeTodayIfNeeded(coinVM: coinVM)
            }
            vm.generateEveningReview(coinVM: coinVM, streakVM: streakVM, journeyVM: journeyVM)
            vm.startAutoRefresh(coinVM: coinVM, streakVM: streakVM)
        }
        .onAppear {
            handleDeepLinkIfNeeded()
        }
        .onChange(of: openActiveWalk) { _, _ in
            handleDeepLinkIfNeeded()
        }
        .onDisappear {
            vm.stopAutoRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.refreshFromHealthKit(coinVM: coinVM, streakVM: streakVM)
        }
        .task {
            await vm.loadRealData()
            coinVM.checkStepTiers(currentSteps: vm.currentSteps)
            if vm.currentSteps >= 1500 {
                streakVM.completeTodayIfNeeded(coinVM: coinVM)
            }
            // Regenerate evening review with real data (onAppear may have run before data loaded)
            vm.generateEveningReview(coinVM: coinVM, streakVM: streakVM, journeyVM: journeyVM)
        }
        .sheet(isPresented: $vm.showHistory) {
            WalkHistoryView()
        }
        .sheet(isPresented: $vm.showEveningDetails) {
            if let review = vm.eveningReview {
                EveningReviewDetailSheet(review: review)
            }
        }
        .sheet(isPresented: $vm.showJourneyDetail) {
            if let journey = journeyVM.activeJourney {
                JourneyDetailView(journey: journey)
            }
        }
        .fullScreenCover(isPresented: $vm.showActiveWalk) {
            ActiveWalkContainerView(
                vm: ActiveWalkViewModel(
                    dailyGoal: vm.stepGoal,
                    stepsBeforeWalk: vm.currentSteps
                ),
                onComplete: { session in
                    vm.onWalkCompleted(session: session)
                    coinVM.earn(amount: 5, source: .walkSession, description: "Walk completed")
                    coinVM.checkStepTiers(currentSteps: session.totalSteps)
                    if session.totalSteps >= 1500 {
                        streakVM.completeTodayIfNeeded(coinVM: coinVM)
                    }
                    journeyVM.addWalkDistance(session.distanceKm, coinVM: coinVM)
                }
            )
        }
    }

    private func handleDeepLinkIfNeeded() {
        guard openActiveWalk else { return }
        openActiveWalk = false
        vm.showActiveWalk = true
    }
}
