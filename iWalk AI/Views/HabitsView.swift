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

                            // Days of month
                            ForEach(1...vm.monthData.daysInMonth, id: \.self) { day in
                                let habitDay = vm.monthData.days.first { $0.dayNumber == day }
                                let completion = habitDay?.completion ?? .none
                                let isSelected = vm.selectedDay?.dayNumber == day

                                ZStack {
                                    Circle()
                                        .fill(dayColor(completion: completion))
                                        .frame(width: 36, height: 36)
                                    if isSelected {
                                        Circle()
                                            .stroke(Color.iwPrimary, lineWidth: 2)
                                            .frame(width: 38, height: 38)
                                    }
                                    Text("\(day)")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(completion == .complete ? .white : Color.iwOnSurface)
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
                            InfoCard(backgroundColor: .iwPrimaryContainer.opacity(0.1)) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selected.date.formatted(.dateTime.weekday(.wide).month().day()))
                                            .font(IWFont.labelLarge())
                                            .foregroundStyle(Color.iwOnSurface)
                                        Text("\(selected.steps.formatted()) steps")
                                            .font(IWFont.titleMedium())
                                            .foregroundStyle(Color.iwPrimary)
                                    }
                                    Spacer()
                                    Text(completionLabel(selected.completion))
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(completionLabelColor(selected.completion))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(completionLabelColor(selected.completion).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Stats Row
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("\(vm.monthData.completedDays)")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)
                                    .contentTransition(.numericText())
                                Text("DAYGOAL")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("\(Int(vm.monthData.completionRate * 100))%")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)
                                    .contentTransition(.numericText())
                                Text("COMPLETION")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text("\(vm.monthData.averageSteps / 1000)k")
                                    .font(IWFont.titleMedium())
                                    .foregroundStyle(Color.iwOnSurface)
                                    .contentTransition(.numericText())
                                Text("AVG STEPS")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 8)
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

    private func dayColor(completion: HabitCompletion) -> Color {
        switch completion {
        case .complete: return .iwPrimary
        case .partial: return .iwPrimaryFixed.opacity(0.4)
        case .none: return .iwSurfaceContainerLow
        }
    }

    private func completionLabel(_ completion: HabitCompletion) -> String {
        switch completion {
        case .complete: "Goal Met"
        case .partial: "Partial"
        case .none: "Missed"
        }
    }

    private func completionLabelColor(_ completion: HabitCompletion) -> Color {
        switch completion {
        case .complete: .iwPrimary
        case .partial: .iwTertiary
        case .none: .iwError
        }
    }
}
