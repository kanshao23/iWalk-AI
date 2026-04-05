import SwiftUI

struct HabitsView: View {
    @State private var vm = HabitsViewModel()
    @Environment(\.streakVM) private var streakVM
    private let daysOfWeek = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                AppHeader(showProfile: true)

                // Current Progress — Streak
                AnimatedCard(delay: 0.1) {
                    InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Current Progress")
                                .font(IWFont.labelMedium())
                                .foregroundStyle(Color.iwOutline)
                                .textCase(.uppercase)
                            HStack {
                                Text("\(streakVM.streak.currentStreak) Days Streak!")
                                    .font(IWFont.titleLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                    .scaleEffect(vm.streakAnimated ? 1.0 : 0.8)
                                    .opacity(vm.streakAnimated ? 1 : 0)
                                Text("🔥")
                                    .font(.system(size: 22))
                                    .scaleEffect(vm.streakAnimated ? 1.0 : 0.5)
                                    .opacity(vm.streakAnimated ? 1 : 0)
                            }
                            Text("You haven't missed a goal since last Tuesday.")
                                .font(IWFont.bodyMedium())
                                .foregroundStyle(Color.iwOutline)
                        }
                    }
                }

                // Freeze Cards
                if streakVM.streak.freezeCardsRemaining > 0 {
                    AnimatedCard(delay: 0.15) {
                        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                            HStack(spacing: 12) {
                                Image(systemName: "snowflake")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.iwSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Freeze Cards")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                    Text("\(streakVM.streak.freezeCardsRemaining) remaining — auto-protects your streak")
                                        .font(IWFont.labelSmall())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                Spacer()
                                HStack(spacing: 4) {
                                    ForEach(0..<3, id: \.self) { i in
                                        Image(systemName: "snowflake")
                                            .font(.system(size: 12))
                                            .foregroundStyle(i < streakVM.streak.freezeCardsRemaining ? Color.iwSecondary : Color.iwOutlineVariant)
                                    }
                                }
                            }
                        }
                    }
                }

                // Monthly Habits Calendar
                AnimatedCard(delay: 0.2) {
                    VStack(spacing: 16) {
                        // Month Header
                        HStack {
                            Text("Monthly Habits")
                                .font(IWFont.titleMedium())
                                .foregroundStyle(Color.iwOnSurface)
                            Spacer()
                            HStack(spacing: 8) {
                                Button { vm.goToPreviousMonth() } label: {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.iwOnSurface)
                                        .frame(width: 28, height: 28)
                                        .background(Color.iwSurfaceContainerLow)
                                        .clipShape(Circle())
                                }
                                Text(vm.monthData.monthYearString)
                                    .font(IWFont.labelLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                    .frame(minWidth: 120)
                                Button { vm.goToNextMonth() } label: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.iwOnSurface)
                                        .frame(width: 28, height: 28)
                                        .background(Color.iwSurfaceContainerLow)
                                        .clipShape(Circle())
                                }
                            }
                        }

                        // Day of week headers
                        HStack(spacing: 0) {
                            ForEach(daysOfWeek, id: \.self) { day in
                                Text(day)
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Calendar grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                            // Offset for first day of month
                            ForEach(0..<vm.monthData.firstWeekdayOffset, id: \.self) { _ in
                                Text("").frame(width: 36, height: 36)
                            }

                            // Days of month — medal icons based on steps
                            ForEach(1...vm.monthData.daysInMonth, id: \.self) { day in
                                let habitDay = vm.monthData.days.first { $0.dayNumber == day }
                                let steps = habitDay?.steps ?? 0
                                let medal = medalForSteps(steps)
                                let isSelected = vm.selectedDay?.dayNumber == day
                                let isFuture = habitDay == nil || (habitDay?.completion == HabitCompletion.none && steps == 0 && day > Calendar.current.component(.day, from: .now))

                                VStack(spacing: 2) {
                                    ZStack {
                                        Circle()
                                            .fill(isFuture ? Color.iwSurfaceContainerLow : medal.color.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        if isSelected {
                                            Circle()
                                                .stroke(medal.color, lineWidth: 2)
                                                .frame(width: 38, height: 38)
                                        }
                                        if !isFuture && medal.emoji != nil {
                                            Text(medal.emoji!)
                                                .font(.system(size: 18))
                                        } else {
                                            Text("\(day)")
                                                .font(IWFont.labelMedium())
                                                .foregroundStyle(Color.iwOnSurface)
                                        }
                                    }
                                    // Day number below medal
                                    if !isFuture && medal.emoji != nil {
                                        Text("\(day)")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(Color.iwOutline)
                                    }
                                }
                                .onTapGesture {
                                    if let habitDay {
                                        vm.selectDay(habitDay)
                                    }
                                }
                            }
                        }

                        // Selected day detail
                        if let selected = vm.selectedDay {
                            let selectedMedal = medalForSteps(selected.steps)
                            InfoCard(backgroundColor: selectedMedal.color.opacity(0.12)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selected.date.formatted(.dateTime.weekday(.wide).month().day()))
                                            .font(IWFont.labelLarge())
                                            .foregroundStyle(Color.iwOnSurface)
                                        Text("\(selected.steps.formatted()) steps")
                                            .font(IWFont.titleMedium())
                                            .foregroundStyle(selectedMedal.color)
                                    }
                                    Spacer()
                                    Text(selectedMedal.label)
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(selectedMedal.color)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedMedal.color.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Medal stats
                        let medalCounts = countMedals(vm.monthData.days)
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("🥉")
                                    .font(.system(size: 20))
                                Text("\(medalCounts.bronze)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Self.bronze)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("🥈")
                                    .font(.system(size: 20))
                                Text("\(medalCounts.silver)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Self.silver)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("🥇")
                                    .font(.system(size: 20))
                                Text("\(medalCounts.gold)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Self.gold)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("💎")
                                    .font(.system(size: 20))
                                Text("\(medalCounts.diamond)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Self.diamond)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("👑")
                                    .font(.system(size: 20))
                                Text("\(medalCounts.legend)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Self.legendary)
                                    .contentTransition(.numericText())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 8)

                        // Average steps
                        Text("Avg: \(vm.monthData.averageSteps.formatted()) steps/day")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                            .padding(.top, 4)
                    }
                }

                // Personal Records
                AnimatedCard(delay: 0.3) {
                    VStack(spacing: 16) {
                        SectionHeader("Personal Records")

                        HStack(spacing: 14) {
                            ForEach(vm.personalRecords, id: \.title) { record in
                                InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                                    VStack(spacing: 8) {
                                        Image(systemName: record.icon)
                                            .font(.system(size: 24))
                                            .foregroundStyle(record.iconColor)
                                        Text(record.title)
                                            .font(IWFont.labelSmall())
                                            .foregroundStyle(Color.iwOutline)
                                            .textCase(.uppercase)
                                        Text(record.value)
                                            .font(IWFont.titleLarge())
                                            .foregroundStyle(Color.iwOnSurface)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }

                // Inspirational Quote
                AnimatedCard(delay: 0.4) {
                    VStack(spacing: 12) {
                        Text("\"\(vm.currentQuote.text)\"")
                            .font(IWFont.bodyLarge())
                            .foregroundStyle(Color.iwOnSurface)
                            .italic()
                            .multilineTextAlignment(.center)
                        HStack {
                            Rectangle()
                                .fill(Color.iwOnSurface)
                                .frame(width: 24, height: 2)
                            Text(vm.currentQuote.author)
                                .font(IWFont.labelMedium())
                                .foregroundStyle(Color.iwOutline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                    .onTapGesture { vm.nextQuote() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
        .background(Color.iwSurface)
        .onAppear { vm.animateOnAppear() }
    }

    // MARK: - Medal system

    private struct MedalInfo {
        let label: String
        let color: Color
        let textWhite: Bool
        let emoji: String?
    }

    private static let bronze = Color(hex: 0xCD7F32)
    private static let silver = Color(hex: 0xA8A9AD)
    private static let gold = Color(hex: 0xB8860B)
    private static let diamond = Color(hex: 0x5B9BD5)
    private static let legendary = Color(hex: 0x9B59B6)

    private func medalForSteps(_ steps: Int) -> MedalInfo {
        switch steps {
        case 20_000...:
            return MedalInfo(label: "Legend", color: Self.legendary, textWhite: true, emoji: "👑")
        case 15_000...:
            return MedalInfo(label: "Beyond", color: Self.diamond, textWhite: true, emoji: "💎")
        case 10_000...:
            return MedalInfo(label: "Gold", color: Self.gold, textWhite: true, emoji: "🥇")
        case 6_500...:
            return MedalInfo(label: "Silver", color: Self.silver, textWhite: false, emoji: "🥈")
        case 3_000...:
            return MedalInfo(label: "Bronze", color: Self.bronze, textWhite: true, emoji: "🥉")
        case 1...:
            return MedalInfo(label: "Started", color: Color.iwSurfaceContainerHigh, textWhite: false, emoji: "👟")
        default:
            return MedalInfo(label: "Rest Day", color: Color.iwSurfaceContainerLow, textWhite: false, emoji: nil)
        }
    }

    private struct MedalCounts {
        var bronze = 0
        var silver = 0
        var gold = 0
        var diamond = 0
        var legend = 0
    }

    private func countMedals(_ days: [HabitDay]) -> MedalCounts {
        var counts = MedalCounts()
        for day in days {
            switch day.steps {
            case 20_000...: counts.legend += 1
            case 15_000...: counts.diamond += 1
            case 10_000...: counts.gold += 1
            case 6_500...: counts.silver += 1
            case 3_000...: counts.bronze += 1
            default: break
            }
        }
        return counts
    }
}
