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

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let trackWidth = geo.size.width
                let trackY: CGFloat = 90
                let walkerX = trackWidth * walkerPosition

                ZStack(alignment: .leading) {
                    // Step count above walker
                    Text(currentSteps.formatted())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: trackY - 80)

                    // Walker icon
                    Image(systemName: "figure.walk")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: trackY - 36)

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

                    // Personal goal star
                    if let pgPos = personalGoalPosition {
                        let pgX = trackWidth * pgPos
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(personalGoal?.isReached == true ? Color.iwPrimary : Color.iwTertiary)
                            .position(x: pgX, y: trackY - 16)
                    }

                    // Goal flag at end
                    VStack(spacing: 0) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(walkerPosition >= 1.0 ? Color.iwPrimary : Color.iwOutlineVariant)
                        Text(goalSteps.formatted())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.iwOutline)
                    }
                    .position(x: trackWidth - 10, y: trackY - 20)
                }
            }
            .frame(height: 130)
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
