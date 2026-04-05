import SwiftUI

struct ShareCardView: View {
    let stats: ShareCardStats

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: iconForType(stats.type))
                .font(.system(size: 40))
                .foregroundStyle(.white)

            Text(stats.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let steps = stats.steps {
                HStack(spacing: 16) {
                    if let distance = stats.distance {
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", distance))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("km")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    VStack(spacing: 2) {
                        Text(steps.formatted())
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text("steps")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    if let coins = stats.coins {
                        VStack(spacing: 2) {
                            Text("+\(coins)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("coins")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }

            if let extra = stats.extraLine {
                Text(extra)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.iwPrimary)
                    )
                Text("iWalk AI")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 360, height: 480)
        .background(gradientForType(stats.type))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func iconForType(_ type: ShareCardType) -> String {
        switch type {
        case .dailySummary: "figure.walk"
        case .streakMilestone: "flame.fill"
        case .journeyMilestone: "mappin.and.ellipse"
        case .badgeUnlock: "medal.fill"
        case .challengeComplete: "trophy.fill"
        case .weeklyReport: "chart.bar.fill"
        }
    }

    private func gradientForType(_ type: ShareCardType) -> LinearGradient {
        switch type {
        case .dailySummary, .weeklyReport:
            return LinearGradient(colors: [.iwPrimary, Color(hex: 0x004D3A)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .streakMilestone:
            return LinearGradient(colors: [.iwTertiary, Color(hex: 0x6B3500)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .journeyMilestone:
            return LinearGradient(colors: [.iwSecondary, Color(hex: 0x064B63)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .badgeUnlock, .challengeComplete:
            return LinearGradient(colors: [Color(hex: 0x6B4FA0), Color(hex: 0x3D2D6B)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Share Helper

struct ShareCardRenderer {
    @MainActor
    static func renderImage(stats: ShareCardStats) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(stats: stats))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
