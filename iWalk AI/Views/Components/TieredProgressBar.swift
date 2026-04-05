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

    private var encouragementText: String {
        isAheadOfSchedule ? "Ahead of schedule!" : "A bit behind — let's walk!"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Walker + bubble + step count
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let walkerX = max(totalWidth * walkerPosition, 40)
                // Bubble offset to the right, clamped to screen
                let bubbleX = min(walkerX + 60, totalWidth - 80)

                ZStack {
                    // Speech bubble — floating above with gap
                    SpeechBubble(text: encouragementText, isPositive: isAheadOfSchedule)
                        .position(x: bubbleX, y: 22)

                    // Walker icon
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: 115)

                    // Step count — below walker with gap
                    Text(currentSteps.formatted())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                        .position(x: walkerX, y: 200)
                }
            }
            .frame(height: 225)

            // Spacer between steps and track
            Spacer().frame(height: 16)

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

// MARK: - Speech Bubble (elliptical comic style)

private struct SpeechBubble: View {
    let text: String
    let isPositive: Bool

    private var bubbleColor: Color {
        isPositive ? Color.iwPrimaryFixed.opacity(0.4) : Color.iwTertiaryFixed.opacity(0.4)
    }

    private var borderColor: Color {
        isPositive ? Color.iwPrimary.opacity(0.3) : Color.iwTertiary.opacity(0.3)
    }

    private var textColor: Color {
        isPositive ? Color.iwPrimary : Color.iwTertiary
    }

    var body: some View {
        VStack(spacing: -1) {
            // Elliptical bubble body
            HStack(spacing: 5) {
                Image(systemName: isPositive ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                    .font(.system(size: 12))
                Text(text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(bubbleColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )

            // Small tail — two shrinking circles to mimic comic bubble
            HStack(spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Circle()
                        .fill(bubbleColor)
                        .overlay(Circle().stroke(borderColor, lineWidth: 1))
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(bubbleColor)
                        .overlay(Circle().stroke(borderColor, lineWidth: 1))
                        .frame(width: 5, height: 5)
                        .offset(x: -3)
                }
                Spacer()
                Spacer()
            }
        }
    }
}
