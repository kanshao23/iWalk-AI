import SwiftUI

struct EveningReviewCard: View {
    let review: EveningReview
    let onViewDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.iwEveningAccent)
                Text("Today's Review")
                    .font(IWFont.titleMedium())
                    .foregroundStyle(.white)
                Spacer()
            }

            HStack(spacing: 4) {
                Text(review.totalSteps.formatted())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("steps")
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(.white.opacity(0.7))
                Text("·")
                    .foregroundStyle(.white.opacity(0.5))
                Text(String(format: "%.1f km", Double(review.totalSteps) / 1400.0))
                    .font(IWFont.bodyMedium())
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { tier in
                    Circle()
                        .fill(tier <= review.tiersReached ? Color.iwPrimaryContainer : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
                Text("Tier \(review.tiersReached) reached")
                    .font(IWFont.labelSmall())
                    .foregroundStyle(.white.opacity(0.7))
            }

            HStack(spacing: 16) {
                Label("+\(review.coinsEarned)", systemImage: "dollarsign.circle.fill")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwTertiaryContainer)

                Label("\(review.streakCount)d", systemImage: "flame.fill")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(Color.iwTertiaryContainer)

                if review.journeyDistanceToday > 0 {
                    Label(String(format: "+%.1f km", review.journeyDistanceToday), systemImage: "map.fill")
                        .font(IWFont.labelMedium())
                        .foregroundStyle(Color.iwSecondaryContainer)
                }
            }

            if let city = review.journeyNextCity, let dist = review.journeyDistanceRemaining {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                    Text("Next: \(city), \(String(format: "%.0f", dist)) km left")
                        .font(IWFont.labelSmall())
                }
                .foregroundStyle(.white.opacity(0.6))
            }

            Text(review.aiSummary)
                .font(IWFont.bodyLarge())
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(3)

            Button(action: onViewDetails) {
                HStack {
                    Text("View Details")
                        .font(IWFont.labelLarge())
                        .fontWeight(.semibold)
                    Spacer()
                    if !review.isViewed {
                        Text("+5 coins")
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwTertiaryContainer)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Color.iwEveningGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
