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

    private var personalGoalPosition: Double? {
        guard let pg = personalGoal else { return nil }
        return min(Double(pg.targetSteps) / Double(visualMax), 1.0)
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

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let trackY: CGFloat = 220
                let walkerX = max(trackWidth * walkerPosition, 30)
                let goalFlagX = trackWidth * min(Double(goalSteps) / Double(visualMax), 1.0)

                ZStack(alignment: .leading) {
                    // Step count above walker
                    Text(currentSteps.formatted())
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: trackY - 210)

                    // Walker icon — feet well above the track
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: trackY - 110)

                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.iwSurfaceContainerHigh)
                        .frame(height: 8)
                        .position(x: trackWidth / 2, y: trackY)

                    // Filled track
                    if walkerPosition > 0.005 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.iwPrimaryGradient)
                            .frame(width: trackWidth * walkerPosition, height: 8)
                            .position(x: (trackWidth * walkerPosition) / 2, y: trackY)
                    }

                    // Tier markers
                    ForEach(tiers) { tier in
                        let x = trackWidth * tierPosition(tier)

                        Circle()
                            .fill(tier.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHighest)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.iwSurfaceContainerLowest, lineWidth: 2)
                            )
                            .scaleEffect(tier.isReached ? 1.0 : 0.85)
                            .position(x: x, y: trackY)

                        // Tier label below
                        Text(tierLabel(tier.stepsRequired))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(tier.isReached ? Color.iwPrimary : Color.iwOutlineVariant)
                            .position(x: x, y: trackY + 18)

                        // Coin reward above (only for reached tiers)
                        if tier.isReached {
                            Text("+\(tier.coinReward)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.iwTertiaryContainer)
                                .position(x: x, y: trackY - 16)
                        }
                    }

                    // Personal goal star — positioned above the track at goal position
                    if let pgPos = personalGoalPosition {
                        let pgX = trackWidth * pgPos
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(personalGoal?.isReached == true ? Color.iwPrimary : Color.iwTertiary)
                            .position(x: pgX, y: trackY - 16)
                    }

                    // Goal flag at the goalSteps position (not at visual max end)
                    VStack(spacing: 0) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(currentSteps >= goalSteps ? Color.iwPrimary : Color.iwOutlineVariant)
                        Text(goalSteps.formatted())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.iwOutline)
                    }
                    .position(x: goalFlagX, y: trackY - 24)
                }
            }
            .frame(height: 260)

            // Encouragement label
            HStack(spacing: 4) {
                Image(systemName: isAheadOfSchedule ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 12))
                Text(isAheadOfSchedule ? "Ahead of schedule!" : "A bit behind — let's walk!")
                    .font(IWFont.labelSmall())
            }
            .foregroundStyle(isAheadOfSchedule ? Color.iwPrimary : Color.iwTertiary)
            .padding(.top, 4)
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
