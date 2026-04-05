import SwiftUI

struct TieredProgressBar: View {
    let currentSteps: Int
    let goalSteps: Int
    let tiers: [StepTier]
    let personalGoal: PersonalGoal?
    var animatedProgress: Double?

    private var scrollableMax: Int { 20_000 }

    // Screen shows 0..goalSteps+15% padding, scrollable to 20k
    private var visibleSteps: Int {
        Int(Double(goalSteps) * 1.15) // 15% extra so Goal ghost isn't clipped
    }

    private func scrollScale(screenWidth: CGFloat) -> CGFloat {
        screenWidth * CGFloat(Double(scrollableMax) / Double(visibleSteps))
    }

    private func xPosition(for steps: Int, in contentWidth: CGFloat) -> CGFloat {
        contentWidth * CGFloat(Double(steps) / Double(scrollableMax))
    }

    /// Expected progress based on time of day (7:00–23:00)
    private var expectedProgress: Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: .now)
        let minute = cal.component(.minute, from: .now)
        let minutesSince7am = (hour - 7) * 60 + minute
        let wakingMinutes = 16 * 60
        return min(max(Double(minutesSince7am) / Double(wakingMinutes), 0), 1.0)
    }

    private var isAheadOfSchedule: Bool {
        let goalProgress = min(Double(currentSteps) / Double(goalSteps), 1.0)
        return goalProgress >= expectedProgress
    }

    private var aiInsight: String {
        let remaining = goalSteps - currentSteps
        let goalProgress = Double(currentSteps) / Double(goalSteps)

        if goalProgress >= 1.0 {
            return "Goal crushed! Keep going to earn bonus tier coins."
        } else if goalProgress >= 0.75 {
            return "Almost there! Just \(remaining.formatted()) steps to your daily goal."
        } else if isAheadOfSchedule {
            return "Great pace! You're ahead of schedule — \(Int(goalProgress * 100))% done."
        } else if goalProgress >= 0.5 {
            return "Halfway there! A 15-min walk will get you back on track."
        } else if goalProgress >= 0.25 {
            return "Good start! Try a walk after lunch to boost your progress."
        } else {
            return "Let's get moving! A short walk can lift your energy and mood."
        }
    }

    // MARK: - Ghost targets

    private struct GhostTarget: Identifiable {
        let id: String
        let steps: Int
        let label: String
        let color: Color
        let reached: Bool
    }

    private var finalGoal: Int { goalSteps }

    private var ghostTargets: [GhostTarget] {
        [
            GhostTarget(id: "min", steps: 3_000, label: "Min",
                        color: .iwTertiary, reached: currentSteps >= 3_000),
            GhostTarget(id: "good", steps: 6_500, label: "Good",
                        color: .iwSecondary, reached: currentSteps >= 6_500),
            GhostTarget(id: "goal", steps: finalGoal, label: "Goal",
                        color: .iwPrimary, reached: currentSteps >= finalGoal),
        ]
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Unified scrollable area: walkers + track
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let contentWidth = scrollScale(screenWidth: screenWidth)

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Walker area
                        ZStack {
                            // Ghost walkers
                            ForEach(ghostTargets) { target in
                                let ghostX = xPosition(for: target.steps, in: contentWidth)
                                ghostWalkerView(target: target)
                                    .position(x: ghostX, y: 105)

                                // Label below ghost
                                VStack(spacing: 1) {
                                    Text(target.label)
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    Text(target.steps.formatted())
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                }
                                .foregroundStyle(target.reached ? target.color : target.color.opacity(0.5))
                                .position(x: ghostX, y: 190)
                            }

                            // Active walker
                            let walkerX = max(xPosition(for: currentSteps, in: contentWidth), 40)

                            // Step count above head
                            Text(currentSteps.formatted())
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.iwPrimary)
                                .contentTransition(.numericText())
                                .position(x: walkerX, y: 16)

                            Image(systemName: "figure.walk")
                                .font(.system(size: 128, weight: .medium))
                                .foregroundStyle(Color.iwPrimary)
                                .position(x: walkerX, y: 105)
                        }
                        .frame(width: contentWidth, height: 210)

                        // Progress track
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.iwSurfaceContainerHigh)
                                .frame(width: contentWidth, height: 14)

                            // Filled track
                            let filledWidth = xPosition(for: currentSteps, in: contentWidth)
                            if filledWidth > 1 {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.iwPrimaryGradient)
                                    .frame(width: filledWidth, height: 14)
                            }

                            // Tier markers
                            ForEach(tiers) { tier in
                                let x = xPosition(for: tier.stepsRequired, in: contentWidth)

                                Circle()
                                    .fill(tier.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHighest)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.iwSurfaceContainerLowest, lineWidth: 2.5)
                                    )
                                    .scaleEffect(tier.isReached ? 1.0 : 0.85)
                                    .offset(x: x - 10)

                                // Tier label below
                                Text(tierLabel(tier.stepsRequired))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(tier.isReached ? Color.iwPrimary : Color.iwOutlineVariant)
                                    .offset(x: x - 12, y: 22)

                                // Coin reward above
                                if tier.isReached {
                                    Text("+\(tier.coinReward)")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color.iwTertiaryContainer)
                                        .offset(x: x - 10, y: -20)
                                }
                            }
                        }
                        .frame(width: contentWidth, height: 55)
                    .padding(.bottom, 4)
                    }
                    .padding(.leading, 10) // prevent left-side clipping
                }
            }
            .frame(height: 280)

            // AI insight card
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.iwPrimary)
                Text(aiInsight)
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwOnSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.iwSurfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.top, 8)

            // Goals legend
            HStack(spacing: 14) {
                HStack(spacing: 3) {
                    Circle().fill(Color.iwTertiary).frame(width: 8, height: 8)
                    Text("Min: 3k")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwTertiary)
                }
                HStack(spacing: 3) {
                    Circle().fill(Color.iwSecondary).frame(width: 8, height: 8)
                    Text("Good: 6.5k")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwSecondary)
                }
                HStack(spacing: 3) {
                    Circle().fill(Color.iwPrimary).frame(width: 8, height: 8)
                    Text("Goal: \(finalGoal.formatted())")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
            .padding(.top, 6)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentSteps) of \(goalSteps) steps")
    }

    // MARK: - Ghost walker view

    @ViewBuilder
    private func ghostWalkerView(target: GhostTarget) -> some View {
        ZStack {
            Image(systemName: "figure.walk")
                .font(.system(size: 128, weight: .medium))
                .foregroundStyle(target.color.opacity(target.reached ? 0.2 : 0.06))
                .overlay(
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(target.color.opacity(target.reached ? 0.3 : 0.15))
                        .mask(DashedMask())
                )

            if target.reached {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(target.color)
                    .background(Circle().fill(Color.iwSurface).frame(width: 22, height: 22))
                    .offset(x: 30, y: -40)
            }
        }
    }

    private func tierLabel(_ steps: Int) -> String {
        if steps >= 1000 {
            return "\(steps / 1000)k"
        }
        return "\(steps)"
    }
}

// MARK: - Dashed mask for ghost outline effect

private struct DashedMask: View {
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 3
            let spacing: CGFloat = 5
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = (Int(y / spacing) % 2 == 0) ? 0 : spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
