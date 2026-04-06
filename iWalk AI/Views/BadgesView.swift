import SwiftUI
import UIKit

struct BadgesView: View {
    @Environment(\.coinVM) private var coinVM
    @Environment(\.streakVM) private var streakVM
    @State private var vm = BadgesViewModel()
    @State private var showSettingsSheet = false
    @State private var showCoinShop = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                AppHeader(onSettingsTap: {
                    showSettingsSheet = true
                })

                HStack {
                    Spacer()
                    Button {
                        showCoinShop = true
                    } label: {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.iwPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.iwPrimaryContainer)
                            .clipShape(Circle())
                    }
                }

                // Local comparison card
                AnimatedCard(delay: 0.1) {
                    InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("This Week vs Last Week")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)
                                Spacer()
                                if vm.isLoadingComparison {
                                    ProgressView().scaleEffect(0.8)
                                }
                            }

                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Text(vm.thisWeekAvg.formatted())
                                        .font(IWFont.labelLarge())
                                        .foregroundStyle(Color.iwPrimary)
                                    Text("This Week")
                                        .font(IWFont.labelSmall())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                .frame(width: 80)

                                Divider().frame(height: 40)

                                VStack(spacing: 2) {
                                    Text(vm.lastWeekAvg.formatted())
                                        .font(IWFont.labelLarge())
                                        .foregroundStyle(Color.iwOutline)
                                    Text("Last Week")
                                        .font(IWFont.labelSmall())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                .frame(width: 80)

                                Spacer()

                                let pct = vm.weekOverWeekPercent
                                HStack(spacing: 4) {
                                    Image(systemName: pct >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                        .foregroundStyle(pct >= 0 ? Color.iwPrimary : Color.iwTertiary)
                                    Text("\(pct >= 0 ? "+" : "")\(pct)%")
                                        .font(IWFont.labelLarge())
                                        .foregroundStyle(pct >= 0 ? Color.iwPrimary : Color.iwTertiary)
                                }
                            }

                            if !vm.thisWeekDaily.isEmpty {
                                let maxSteps = max(
                                    vm.thisWeekDaily.map(\.steps).max() ?? 1,
                                    vm.lastWeekDaily.map(\.steps).max() ?? 1,
                                    1
                                )
                                HStack(alignment: .bottom, spacing: 6) {
                                    ForEach(0..<min(7, vm.thisWeekDaily.count), id: \.self) { i in
                                        VStack(spacing: 2) {
                                            ZStack(alignment: .bottom) {
                                                if i < vm.lastWeekDaily.count {
                                                    let h = CGFloat(vm.lastWeekDaily[i].steps) / CGFloat(maxSteps)
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(Color.iwSurfaceContainerHigh)
                                                        .frame(height: max(4, 50 * h))
                                                        .frame(maxWidth: .infinity)
                                                }
                                                let h = CGFloat(vm.thisWeekDaily[i].steps) / CGFloat(maxSteps)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.iwPrimary.opacity(0.85))
                                                    .frame(height: max(4, 50 * h))
                                                    .frame(maxWidth: .infinity)
                                            }
                                            .frame(height: 50)
                                            Text(vm.thisWeekDaily[i].shortDayName)
                                                .font(IWFont.labelSmall())
                                                .foregroundStyle(Color.iwOutline)
                                        }
                                    }
                                }
                            }

                            Text(vm.comparisonMessage)
                                .font(IWFont.labelMedium())
                                .foregroundStyle(Color.iwOutline)
                        }
                    }
                }

                // Active Challenges
                AnimatedCard(delay: 0.2) {
                    VStack(spacing: 16) {
                        SectionHeader("Active Challenges")

                        ForEach(vm.challenges) { challenge in
                            ChallengeCard(
                                challenge: challenge,
                                isExpanded: vm.expandedChallengeId == challenge.id,
                                isAnimated: vm.challengeAnimated[challenge.id] ?? false,
                                onTap: { vm.toggleExpandChallenge(challenge) },
                                onToggleJoin: { vm.toggleChallenge(challenge) }
                            )
                        }
                    }
                }

                // My Badges
                AnimatedCard(delay: 0.3) {
                    VStack(spacing: 16) {
                        SectionHeader("My Badges")

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                            GridItem(.flexible(), spacing: 14),
                        ], spacing: 14) {
                            ForEach(vm.badges) { badge in
                                BadgeCell(badge: badge)
                                    .onTapGesture { vm.selectedBadge = badge }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.iwSurface)
        .onAppear { vm.animateOnAppear() }
        .task { await vm.loadComparisonData() }
        .sheet(item: $vm.selectedBadge) { badge in
            BadgeDetailSheet(badge: badge)
        }
        .sheet(isPresented: $showSettingsSheet) {
            AppSettingsSheet()
        }
        .sheet(isPresented: $showCoinShop) {
            CoinShopView(coinVM: coinVM, streakVM: streakVM)
        }
    }
}

private struct AppSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.coinVM) private var coinVM
    @Environment(\.streakVM) private var streakVM
    @Environment(\.journeyVM) private var journeyVM

    @AppStorage("hasSubscribed") private var hasSubscribed = false
    @AppStorage("iw_daily_reminder_enabled") private var dailyReminderEnabled = true
    @AppStorage("iw_streak_risk_reminder_enabled") private var streakRiskReminderEnabled = true
    @AppStorage("iw_evening_review_reminder_enabled") private var eveningReviewReminderEnabled = false
    @AppStorage("iw_daily_reminder_hour") private var reminderHour = 20
    @AppStorage("iw_daily_reminder_minute") private var reminderMinute = 0

    @State private var personalGoalSteps = 10_000
    @State private var isRequestingHealthAccess = false
    @State private var showResetConfirm = false
    @State private var actionFeedback: String?

    private let healthKit = HealthKitManager.shared

    private var reminderDateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newValue in
                reminderHour = Calendar.current.component(.hour, from: newValue)
                reminderMinute = Calendar.current.component(.minute, from: newValue)
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let actionFeedback {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.iwPrimary)
                        Text(actionFeedback)
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOnSurface)
                    }
                    .listRowBackground(Color.iwPrimaryFixed.opacity(0.2))
                }

                Section("Subscription") {
                    HStack {
                        Text("Plan status")
                        Spacer()
                        Text(hasSubscribed ? "Active" : "Free")
                            .foregroundStyle(hasSubscribed ? Color.iwPrimary : Color.iwOutline)
                    }
                    Button {
                        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
                        openURL(url)
                    } label: {
                        Label("Manage Subscription", systemImage: "creditcard")
                    }
                }

                Section("Goals") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Personal Step Goal")
                            Spacer()
                            Text("\(personalGoalSteps.formatted())")
                                .foregroundStyle(Color.iwPrimary)
                        }
                        Stepper(value: $personalGoalSteps, in: 3_000...30_000, step: 250) {}
                            .labelsHidden()
                    }
                    .onChange(of: personalGoalSteps) { _, newValue in
                        coinVM.setPersonalGoal(targetSteps: newValue)
                    }

                    HStack {
                        Text("Reward per goal")
                        Spacer()
                        Text("+\(coinVM.personalGoal.coinReward) coins")
                            .foregroundStyle(Color.iwOutline)
                    }
                }

                Section("Reminders") {
                    Toggle("Daily walk reminder", isOn: $dailyReminderEnabled)
                    Toggle("Streak risk reminder", isOn: $streakRiskReminderEnabled)
                    Toggle("Evening review reminder", isOn: $eveningReviewReminderEnabled)

                    if dailyReminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: reminderDateBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("Health Data") {
                    HStack {
                        Text("HealthKit access")
                        Spacer()
                        Text(healthKit.isAuthorized ? "Connected" : "Not connected")
                            .foregroundStyle(healthKit.isAuthorized ? Color.iwPrimary : Color.iwOutline)
                    }

                    if !healthKit.isAuthorized {
                        Button {
                            requestHealthKitAccess()
                        } label: {
                            Label("Connect HealthKit", systemImage: "heart.text.square")
                        }
                        .disabled(isRequestingHealthAccess)
                    }

                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        Label("Open iOS Settings", systemImage: "gear")
                    }
                }

                Section("Data Management") {
                    Button {
                        UserDefaults.standard.removeObject(forKey: "iw_coach_messages_v1")
                        actionFeedback = "Coach conversation history cleared."
                    } label: {
                        Label("Clear Coach History", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Progress Data", systemImage: "exclamationmark.triangle")
                    }
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("iWalk AI")
                            .foregroundStyle(Color.iwOutline)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("Beta")
                            .foregroundStyle(Color.iwOutline)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.iwSurface)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.iwPrimary)
                }
            }
            .confirmationDialog(
                "Reset all local progress data?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    coinVM.resetAllData()
                    streakVM.resetAllData()
                    journeyVM.resetAllData()
                    UserDefaults.standard.removeObject(forKey: "iw_coach_messages_v1")
                    actionFeedback = "Local progress reset completed."
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears coins, streak, journey progress, and coach history on this device.")
            }
            .onAppear {
                personalGoalSteps = coinVM.personalGoal.targetSteps
            }
        }
    }

    private func requestHealthKitAccess() {
        guard !isRequestingHealthAccess else { return }
        isRequestingHealthAccess = true
        Task {
            _ = await healthKit.requestAuthorization()
            await MainActor.run {
                isRequestingHealthAccess = false
                actionFeedback = healthKit.isAuthorized
                ? "HealthKit connected successfully."
                : "HealthKit authorization was not granted."
            }
        }
    }
}

// MARK: - Challenge Card

private struct ChallengeCard: View {
    let challenge: Challenge
    let isExpanded: Bool
    let isAnimated: Bool
    let onTap: () -> Void
    let onToggleJoin: () -> Void

    var body: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: challenge.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(challenge.iconColor)
                        .frame(width: 48, height: 48)
                        .background(challenge.iconColor.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challenge.name)
                            .font(IWFont.titleMedium())
                            .foregroundStyle(Color.iwOnSurface)
                        if challenge.isJoined {
                            Text("\(challenge.currentValue.formatted()) / \(challenge.goalValue.formatted()) \(challenge.unit)")
                                .font(IWFont.bodyMedium())
                                .foregroundStyle(Color.iwOutline)
                        }
                    }
                    Spacer()

                    if challenge.isJoined {
                        Text("\(challenge.progressPercent)%")
                            .font(IWFont.titleMedium())
                            .foregroundStyle(Color.iwPrimary)
                            .fontWeight(.semibold)
                    } else {
                        Button("Join") { onToggleJoin() }
                            .font(IWFont.labelLarge())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.iwPrimary)
                            .clipShape(Capsule())
                    }
                }

                if challenge.isJoined {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.iwSurfaceContainerHigh)
                                .frame(height: 10)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.iwPrimaryGradient)
                                .frame(width: geometry.size.width * (isAnimated ? challenge.progress : 0), height: 10)
                                .animation(.easeOut(duration: 0.8), value: isAnimated)
                        }
                    }
                    .frame(height: 10)
                }

                if isExpanded {
                    Text(challenge.description)
                        .font(IWFont.bodyMedium())
                        .foregroundStyle(Color.iwOutline)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    if challenge.isJoined {
                        Button("Leave Challenge") { onToggleJoin() }
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwError)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Badge Cell

private struct BadgeCell: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.color.opacity(0.2) : Color.iwSurfaceContainerHigh)
                    .frame(width: 60, height: 60)
                Image(systemName: badge.isUnlocked ? badge.icon : "lock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(badge.isUnlocked ? badge.color : Color.iwOutline)
            }
            Text(badge.name)
                .font(IWFont.labelSmall())
                .foregroundStyle(badge.isUnlocked ? Color.iwOnSurface : Color.iwOutline)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !badge.isUnlocked && badge.progress > 0 {
                // Mini progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.iwSurfaceContainerHigh)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(badge.color)
                            .frame(width: geo.size.width * badge.progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.iwSurfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(badge.isUnlocked ? 1.0 : 0.7)
    }
}

// MARK: - Leaderboard Sheet

private struct LeaderboardSheet: View {
    let entries: [LeaderboardEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                HStack {
                    Text("#\(entry.rank)")
                        .font(IWFont.titleMedium())
                        .foregroundStyle(entry.rank <= 3 ? Color.iwPrimary : Color.iwOutline)
                        .frame(width: 50, alignment: .leading)
                    Text(entry.name)
                        .font(IWFont.bodyLarge())
                        .foregroundStyle(Color.iwOnSurface)
                        .fontWeight(entry.isCurrentUser ? .bold : .regular)
                    Spacer()
                    Text(entry.steps.formatted())
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwOutline)
                    Text("steps")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwOutline)
                }
                .listRowBackground(entry.isCurrentUser ? Color.iwPrimaryFixed.opacity(0.15) : Color.iwSurfaceContainerLowest)
            }
            .scrollContentBackground(.hidden)
            .background(Color.iwSurface)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }
}

// MARK: - Badge Detail Sheet

private struct BadgeDetailSheet: View {
    let badge: Badge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Circle()
                .fill(badge.isUnlocked ? badge.color.opacity(0.2) : Color.iwSurfaceContainerHigh)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: badge.isUnlocked ? badge.icon : "lock.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(badge.isUnlocked ? badge.color : Color.iwOutline)
                )

            Text(badge.name)
                .font(IWFont.headlineMedium())
                .foregroundStyle(Color.iwOnSurface)

            Text(badge.description)
                .font(IWFont.bodyLarge())
                .foregroundStyle(Color.iwOutline)
                .multilineTextAlignment(.center)

            InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                VStack(spacing: 8) {
                    Text("Requirement")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwOutline)
                    Text(badge.requirement)
                        .font(IWFont.titleMedium())
                        .foregroundStyle(Color.iwOnSurface)
                    if badge.isUnlocked, let date = badge.unlockedDate {
                        Text("Unlocked on \(date.formatted(.dateTime.month().day().year()))")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwPrimary)
                    } else if badge.progress > 0 {
                        Text("Progress: \(Int(badge.progress * 100))%")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if badge.isUnlocked {
                Button {
                    // Share using system share sheet
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Achievement")
                    }
                    .font(IWFont.labelLarge())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.iwPrimaryGradient)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            Button("Done") { dismiss() }
                .font(IWFont.labelLarge())
                .foregroundStyle(Color.iwPrimary)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 32)
        .background(Color.iwSurface)
        .presentationDetents([.medium])
    }
}

extension Badge: Hashable {
    static func == (lhs: Badge, rhs: Badge) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
