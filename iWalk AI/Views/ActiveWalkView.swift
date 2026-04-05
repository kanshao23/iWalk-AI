import SwiftUI

// MARK: - Container

struct ActiveWalkContainerView: View {
    @State var vm: ActiveWalkViewModel
    let onComplete: (WalkSession) -> Void

    var body: some View {
        ZStack {
            // Animated gradient background
            WalkBackground(progress: vm.gradientProgress, isPaused: vm.isPaused)
                .ignoresSafeArea()

            switch vm.phase {
            case .countdown(let count):
                CountdownOverlay(count: count)
            case .active, .paused:
                ActiveWalkContent(vm: vm)
            case .summary(let session):
                WalkSummaryContent(session: session, onDone: { onComplete(session) })
            }

            // Milestone toast
            if vm.showMilestoneToast, let milestone = vm.currentMilestone {
                VStack {
                    MilestoneToast(milestone: milestone)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { vm.startCountdown() }
        .statusBarHidden()
    }
}

// MARK: - Countdown Overlay

private struct CountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Text(count > 0 ? "\(count)" : "GO!")
                .font(count > 0 ? IWFont.displayLarge() : .system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? .white : Color.iwPrimaryFixed)
                .scaleEffect(1.0)
                .id(count) // Force re-render for each number
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 2.5).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    )
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Active Walk Content

private struct ActiveWalkContent: View {
    @Bindable var vm: ActiveWalkViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Elapsed Time — top
            VStack(spacing: 4) {
                Text("ELAPSED")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(2)
                Text(vm.elapsedFormatted)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                if !vm.usesRealPedometer {
                    Text("SIMULATED")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 2)
                }
            }
            .padding(.top, 60)

            Spacer()

            // Progress Ring — center
            ZStack {
                StepProgressRing(
                    currentSteps: vm.totalSteps,
                    goalSteps: vm.dailyGoal,
                    lineWidth: 14,
                    animatedProgress: vm.goalProgress
                )
                .frame(width: 220, height: 220)
            }

            // Session steps
            VStack(spacing: 4) {
                Text("+\(vm.sessionSteps.formatted())")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.iwPrimaryFixed)
                    .contentTransition(.numericText())
                Text("steps this walk")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)

            Spacer()

            // Stats Grid — 2x2
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                WalkStatCell(icon: "speedometer", value: vm.paceFormatted, label: "min/km", iconColor: .iwSecondary)
                WalkStatCell(icon: "mappin.and.ellipse", value: String(format: "%.2f", vm.sessionDistanceKm), label: "km", iconColor: .iwPrimaryContainer)
                WalkStatCell(icon: "flame.fill", value: "\(vm.sessionCalories)", label: "kcal", iconColor: .iwTertiaryContainer)
                HeartRateStatCell(bpm: vm.currentHeartRate, zone: vm.heartRateZone, zoneColor: vm.heartRateZoneColor)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Bottom Buttons
            HStack(spacing: 16) {
                // Pause / Resume
                Button {
                    if vm.isPaused { vm.resume() } else { vm.pause() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(vm.isPaused ? "Resume" : "Pause")
                            .font(IWFont.labelLarge())
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                // End Walk
                Button {
                    vm.endWalk()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("End Walk")
                            .font(IWFont.labelLarge())
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.iwError)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Walk Stat Cell

private struct WalkStatCell: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct HeartRateStatCell: View {
    let bpm: Int
    let zone: String
    let zoneColor: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(zoneColor)
                .symbolEffect(.pulse)
            Text("\(bpm)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(zone)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(zoneColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Milestone Toast

private struct MilestoneToast: View {
    let milestone: WalkMilestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.icon)
                .font(.system(size: 24))
                .foregroundStyle(milestone.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(IWFont.titleMedium())
                    .foregroundStyle(.white)
                Text("Keep going!")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Walk Summary

private struct WalkSummaryContent: View {
    let session: WalkSession
    let onDone: () -> Void

    @State private var ringAnimated = false
    @State private var statsAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.iwPrimaryFixed)
                    Text("Walk Complete!")
                        .font(IWFont.headlineLarge())
                        .foregroundStyle(.white)
                }

                // Before vs After Ring
                ZStack {
                    // Before (dimmed)
                    StepProgressRing(
                        currentSteps: session.stepsBeforeWalk,
                        goalSteps: session.dailyGoal,
                        lineWidth: 10,
                        animatedProgress: session.goalProgressBefore
                    )
                    .opacity(0.3)
                    .frame(width: 160, height: 160)

                    // After (bright)
                    StepProgressRing(
                        currentSteps: session.totalSteps,
                        goalSteps: session.dailyGoal,
                        lineWidth: 12,
                        animatedProgress: ringAnimated ? session.goalProgressAfter : session.goalProgressBefore
                    )
                    .frame(width: 160, height: 160)
                }

                // Stats Card
                VStack(spacing: 16) {
                    SummaryRow(icon: "clock.fill", label: "Duration", value: session.elapsedFormatted, color: .iwSecondary)
                    SummaryRow(icon: "figure.walk", label: "Steps", value: session.steps.formatted(), color: .iwPrimary)
                    SummaryRow(icon: "mappin.and.ellipse", label: "Distance", value: String(format: "%.2f km", session.distanceKm), color: .iwPrimaryContainer)
                    SummaryRow(icon: "flame.fill", label: "Calories", value: "\(session.calories) kcal", color: .iwTertiaryContainer)
                    SummaryRow(icon: "speedometer", label: "Avg Pace", value: "\(session.paceFormatted) min/km", color: .iwSecondaryFixedDim)
                    SummaryRow(icon: "heart.fill", label: "Avg Heart Rate", value: "\(session.averageHeartRate) bpm", color: .iwError)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .opacity(statsAppeared ? 1 : 0)
                .offset(y: statsAppeared ? 0 : 20)

                // Milestone Badge
                if let milestone = session.highestMilestone {
                    HStack(spacing: 12) {
                        Image(systemName: milestone.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(milestone.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.title)
                                .font(IWFont.titleMedium())
                                .foregroundStyle(.white)
                            Text("You reached \(Int(milestone.threshold * 100))% of your daily goal!")
                                .font(IWFont.bodyMedium())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(20)
                    .background(milestone.color.opacity(0.2))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                }

                // Done Button
                Button(action: onDone) {
                    Text("Done")
                        .font(IWFont.labelLarge())
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.iwPrimaryGradient)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringAnimated = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                statsAppeared = true
            }
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(IWFont.bodyMedium())
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(IWFont.titleMedium())
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Animated Background

private struct WalkBackground: View {
    let progress: Double
    let isPaused: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color.iwPrimary.opacity(0.8 + progress * 0.2),
                    Color(hex: 0x0A1F18),
                    Color(hex: 0x0D0D0F),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Ambient glow that shifts with progress
            RadialGradient(
                colors: [
                    Color.iwPrimaryContainer.opacity(0.15 + progress * 0.15),
                    .clear,
                ],
                center: UnitPoint(x: 0.3 + phase * 0.4, y: 0.2),
                startRadius: 50,
                endRadius: 350
            )
        }
        .animation(.easeInOut(duration: 3.0), value: progress)
        .onAppear {
            withAnimation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
        .onChange(of: isPaused) {
            // Animation naturally continues/pauses with SwiftUI
        }
    }
}
