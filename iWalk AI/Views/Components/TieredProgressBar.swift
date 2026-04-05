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

    /// Pixel offset for the walker icon (based on screen width ~350pt)
    private var walkerOffset: CGFloat {
        // Approximate: figure.walk at 128pt is ~60pt wide, offset from leading edge
        let screenWidth: CGFloat = UIScreen.main.bounds.width - 40 // minus padding
        return screenWidth * walkerPosition - 30
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
            // Walker with speech bubble
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let walkerX = max(totalWidth * walkerPosition, 30)
                // Bubble sits to the right of the walker's head
                let bubbleX = min(walkerX + 70, totalWidth - 80)

                ZStack(alignment: .topLeading) {
                    // Walker icon
                    Image(systemName: "figure.walk")
                        .font(.system(size: 128, weight: .medium))
                        .foregroundStyle(Color.iwPrimary)
                        .position(x: walkerX, y: 80)

                    // Speech bubble
                    SpeechBubble(text: encouragementText, isPositive: isAheadOfSchedule)
                        .position(x: bubbleX, y: 16)
                }
            }
            .frame(height: 160)

            // Step count below walker
            Text(currentSteps.formatted())
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color.iwPrimary)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

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

// MARK: - Speech Bubble

private struct SpeechBubble: View {
    let text: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
        }
        .foregroundStyle(isPositive ? Color.iwPrimary : Color.iwTertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isPositive
                ? Color.iwPrimaryFixed.opacity(0.3)
                : Color.iwTertiaryFixed.opacity(0.3)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            // Bubble tail pointing down-left toward walker's head
            Triangle()
                .fill(isPositive ? Color.iwPrimaryFixed.opacity(0.3) : Color.iwTertiaryFixed.opacity(0.3))
                .frame(width: 12, height: 8)
                .offset(x: -20, y: 4),
            alignment: .bottom
        )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
