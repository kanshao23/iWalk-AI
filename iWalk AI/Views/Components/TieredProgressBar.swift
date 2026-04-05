import SwiftUI

struct TieredProgressBar: View {
    let currentSteps: Int
    let goalSteps: Int
    let tiers: [StepTier]
    let personalGoal: PersonalGoal?
    var animatedProgress: Double?

    // The visible range ends at goalSteps by default.
    // The full scrollable range goes to the highest tier (20k).
    private var visibleMax: Int { goalSteps }
    private var scrollableMax: Int { 20_000 }

    // How wide the full scrollable content is relative to screen width
    private var scrollScale: Double {
        Double(scrollableMax) / Double(visibleMax)
    }

    private func tierPosition(_ tier: StepTier, in width: CGFloat) -> CGFloat {
        width * CGFloat(Double(tier.stepsRequired) / Double(scrollableMax))
    }

    private var walkerFraction: Double {
        min(Double(currentSteps) / Double(scrollableMax), 1.0)
    }

    private var goalFraction: Double {
        min(Double(goalSteps) / Double(scrollableMax), 1.0)
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

    // Three ghost milestones
    private var ghostTargets: [(steps: Int, label: String, color: Color)] {
        let minimumSteps = 1_500 // streak minimum
        let myGoalSteps = personalGoal?.targetSteps ?? 0
        var targets: [(steps: Int, label: String, color: Color)] = []

        if currentSteps < minimumSteps {
            targets.append((minimumSteps, "Min", .iwTertiary))
        }
        if myGoalSteps > 0 && currentSteps < myGoalSteps && myGoalSteps != goalSteps {
            targets.append((myGoalSteps, "My Goal", .iwSecondary))
        }
        if currentSteps < goalSteps {
            targets.append((goalSteps, "Goal", .iwPrimary))
        }
        return targets
    }

    var body: some View {
        VStack(spacing: 0) {
            // Walker + ghost targets + step count
            GeometryReader { geo in
                let screenWidth = geo.size.width
                let walkerVisibleFrac = min(Double(currentSteps) / Double(visibleMax), 1.0)
                let walkerX = max(screenWidth * walkerVisibleFrac, 40)

                ZStack {
                    // Ghost walkers at each target position
                    ForEach(Array(ghostTargets.enumerated()), id: \.offset) { _, target in
                        let frac = min(Double(target.steps) / Double(visibleMax), 0.95)
                        let ghostX = max(screenWidth * frac, 60)

                        // Ghost figure
                        Image(systemName: "figure.walk")
                            .font(.system(size: 80, weight: .medium))
                            .foregroundStyle(target.color.opacity(0.15))
                            .overlay(
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundStyle(target.color.opacity(0.3))
                                    .mask(
                                        StripedMask()
                                            .frame(width: 52, height: 100)
                                    )
                            )
                            .position(x: ghostX, y: 96)

                        // Label + step count below ghost
                        VStack(spacing: 1) {
                            Text(target.label)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                            Text(target.steps.formatted())
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(target.color.opacity(0.6))
                        .position(x: ghostX, y: 155)
                    }

                    // Active walker (larger, solid)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: 80)

                    // Step count below walker
                    Text(currentSteps.formatted())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: 166)
                }
            }
            .frame(height: 190)

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
            .padding(.bottom, 16)

            // Scrollable progress track
            GeometryReader { geo in
                let screenWidth = geo.size.width
                // Full content width: screen fills 0..goalSteps, rest scrolls
                let contentWidth = screenWidth * scrollScale

                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.iwSurfaceContainerHigh)
                            .frame(width: contentWidth, height: 14)

                        // Filled track
                        let filledWidth = contentWidth * walkerFraction
                        if filledWidth > 1 {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.iwPrimaryGradient)
                                .frame(width: filledWidth, height: 14)
                        }

                        // Tier markers
                        ForEach(tiers) { tier in
                            let x = tierPosition(tier, in: contentWidth)

                            // Marker circle
                            Circle()
                                .fill(tier.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHighest)
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.iwSurfaceContainerLowest, lineWidth: 2.5)
                                )
                                .scaleEffect(tier.isReached ? 1.0 : 0.85)
                                .offset(x: x - 10) // center the circle

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
                    .frame(width: contentWidth, height: 50)
                    .padding(.vertical, 4)
                }
            }
            .frame(height: 58)

            // Goals legend
            HStack(spacing: 14) {
                // Minimum (orange)
                HStack(spacing: 3) {
                    Circle().fill(Color.iwTertiary).frame(width: 8, height: 8)
                    Text("Min: 1.5k")
                        .font(IWFont.labelSmall())
                        .foregroundStyle(Color.iwTertiary)
                }

                // My Goal (blue)
                if let pg = personalGoal {
                    HStack(spacing: 3) {
                        Circle().fill(Color.iwSecondary).frame(width: 8, height: 8)
                        Text("My: \(pg.targetSteps.formatted())")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwSecondary)
                    }
                }

                // Daily Goal (green)
                HStack(spacing: 3) {
                    Circle().fill(Color.iwPrimary).frame(width: 8, height: 8)
                    Text("Goal: \(goalSteps.formatted())")
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

    private func tierLabel(_ steps: Int) -> String {
        if steps >= 1000 {
            return "\(steps / 1000)k"
        }
        return "\(steps)"
    }
}

// MARK: - Striped mask for dashed ghost effect

private struct StripedMask: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 5
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 2.5)
                context.fill(Path(rect), with: .color(.white))
                y += spacing
            }
        }
    }
}
