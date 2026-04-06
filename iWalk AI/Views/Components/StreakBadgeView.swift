import SwiftUI

struct StreakBadgeView: View {
    let streak: StreakData
    var compact: Bool = true

    var body: some View {
        if compact {
            compactView
        } else {
            expandedView
        }
    }

    private var compactView: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(streak.currentStreak > 0 ? Color.iwTertiaryContainer : Color.iwOutlineVariant)
            Text("\(streak.currentStreak)")
                .font(IWFont.labelLarge())
                .fontWeight(.bold)
                .foregroundStyle(Color.iwOnSurface)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.iwSurfaceContainerLow)
        .clipShape(Capsule())
    }

    private var expandedView: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.iwTertiaryContainer)
                    Text("\(streak.currentStreak) Day Streak")
                        .font(IWFont.titleMedium())
                        .foregroundStyle(Color.iwOnSurface)
                    Spacer()
                    if let next = streak.nextMilestone, let days = streak.daysToNextMilestone {
                        Text("\(days)d to \(next)-day")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                }

                HStack(spacing: 16) {
                    Label("Best: \(streak.longestStreak)d", systemImage: "trophy.fill")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwOutline)

                    if streak.freezeCardsRemaining > 0 {
                        Label("\(streak.freezeCardsRemaining) freeze", systemImage: "snowflake")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwSecondary)
                    }
                }

                if streak.isAtRisk && streak.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text("Walk 1,500 steps to keep your streak!")
                            .font(IWFont.labelMedium())
                    }
                    .foregroundStyle(Color.iwTertiary)
                    .padding(.top, 4)
                }
            }
        }
    }
}
