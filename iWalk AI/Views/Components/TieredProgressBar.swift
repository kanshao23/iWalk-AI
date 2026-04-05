import SwiftUI

struct TieredProgressBar: View {
    let currentSteps: Int
    let goalSteps: Int
    let tiers: [StepTier]
    let personalGoal: PersonalGoal?
    var animatedProgress: Double?

    private var visualMax: Int { 20_000 }

    private func tierPosition(_ tier: StepTier) -> Double {
        min(Double(tier.stepsRequired) / Double(visualMax), 1.0)
    }

    private var walkerPosition: Double {
        min(Double(currentSteps) / Double(visualMax), 1.0)
    }

    /// Expected progress based on time of day (7:00–23:00 waking hours)
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

    var body: some View {
        VStack(spacing: 0) {
            // Walker + ghost target + step count
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let walkerX = max(totalWidth * walkerPosition, 40)
                let goalPosition = min(Double(goalSteps) / Double(visualMax), 1.0)
                let goalX = totalWidth * goalPosition
                let showGhost = currentSteps < goalSteps

                ZStack {
                    // Ghost walker at goal position (dashed outline)
                    if showGhost {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 128, weight: .medium))
                            .foregroundStyle(Color.iwPrimary.opacity(0.12))
                            .overlay(
                                Image(systemName: "figure.walk")
                                    .font(.system(size: 128, weight: .medium))
                                    .foregroundStyle(.clear)
                                    .overlay(
                                        Image(systemName: "figure.walk")
                                            .font(.system(size: 128, weight: .medium))
                                            .foregroundStyle(Color.iwPrimary.opacity(0.25))
                                            .mask(
                                                StripedMask()
                                                    .frame(width: 80, height: 150)
                                            )
                                    )
                            )
                            .position(x: goalX, y: 80)

                        // Goal label below ghost
                        Text(goalSteps.formatted())
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.iwOutlineVariant)
                            .position(x: goalX, y: 166)
                    }

                    // Active walker icon
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: 80)

                    // Step count — below walker, follows walker
                    Text(currentSteps.formatted())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: 166)
                }
            }
            .frame(height: 190)

            // AI insight card — centered
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

            // Track with tier markers
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let trackY: CGFloat = 10

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.iwSurfaceContainerHigh)
                        .frame(height: 14)
                        .position(x: trackWidth / 2, y: trackY)

                    // Filled track
                    if walkerPosition > 0.005 {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.iwPrimaryGradient)
                            .frame(width: trackWidth * walkerPosition, height: 14)
                            .position(x: (trackWidth * walkerPosition) / 2, y: trackY)
                    }

                    // Tier markers
                    ForEach(tiers) { tier in
                        let x = trackWidth * tierPosition(tier)

                        Circle()
                            .fill(tier.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHighest)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.iwSurfaceContainerLowest, lineWidth: 2.5)
                            )
                            .scaleEffect(tier.isReached ? 1.0 : 0.85)
                            .position(x: x, y: trackY)

                        // Tier label below
                        Text(tierLabel(tier.stepsRequired))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(tier.isReached ? Color.iwPrimary : Color.iwOutlineVariant)
                            .position(x: x, y: trackY + 22)

                        // Coin reward above (only for reached tiers)
                        if tier.isReached {
                            Text("+\(tier.coinReward)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.iwTertiaryContainer)
                                .position(x: x, y: trackY - 20)
                        }
                    }
                }
            }
            .frame(height: 50)

            // Goals row below track
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(currentSteps >= goalSteps ? Color.iwPrimary : Color.iwOutlineVariant)
                    Text("Daily Goal: \(goalSteps.formatted())")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwOutline)
                }

                if let pg = personalGoal {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(pg.isReached ? Color.iwPrimary : Color.iwTertiary)
                        Text("My Goal: \(pg.targetSteps.formatted())")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(pg.isReached ? Color.iwPrimary : Color.iwTertiary)
                    }
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
