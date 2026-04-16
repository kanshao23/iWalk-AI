import SwiftUI

struct EveningReviewDetailSheet: View {
    let review: EveningReview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Steps hero
                    VStack(spacing: 6) {
                        Text(review.totalSteps.formatted())
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.iwPrimary)
                        Text("steps today")
                            .font(IWFont.bodyLarge())
                            .foregroundStyle(Color.iwOutline)
                        Text(String(format: "%.2f km walked", Double(review.totalSteps) / 1400.0))
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Metrics row
                    HStack(spacing: 0) {
                        DetailMetric(
                            icon: "star.fill",
                            value: "Tier \(review.tiersReached)",
                            label: "Reached",
                            color: .iwPrimaryContainer
                        )
                        Divider().frame(height: 44)
                        DetailMetric(
                            icon: "dollarsign.circle.fill",
                            value: "+\(review.coinsEarned)",
                            label: "Coins",
                            color: .iwTertiaryContainer
                        )
                        Divider().frame(height: 44)
                        DetailMetric(
                            icon: "flame.fill",
                            value: "\(review.streakCount)d",
                            label: "Streak",
                            color: .iwTertiaryContainer
                        )
                    }
                    .padding(.vertical, 12)
                    .background(Color.iwSurfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Journey progress
                    if review.journeyDistanceToday > 0 || review.journeyNextCity != nil {
                        InfoCard(backgroundColor: .iwSurfaceContainerLow) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.iwSecondary)
                                    Text("Journey Progress")
                                        .font(IWFont.labelMedium())
                                        .foregroundStyle(Color.iwOutline)
                                }
                                if review.journeyDistanceToday > 0 {
                                    Text(String(format: "+%.1f km added today", review.journeyDistanceToday))
                                        .font(IWFont.titleMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                }
                                if let city = review.journeyNextCity, let dist = review.journeyDistanceRemaining {
                                    Text(String(format: "Next stop: %@, %.0f km away", city, dist))
                                        .font(IWFont.bodyLarge())
                                        .foregroundStyle(Color.iwOutline)
                                }
                            }
                        }
                    }

                    // AI summary
                    InfoCard(backgroundColor: .iwPrimaryFixed.opacity(0.08)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.iwPrimary)
                                Text("Coach Summary")
                                    .font(IWFont.labelMedium())
                                    .foregroundStyle(Color.iwPrimary)
                            }
                            Text(review.aiSummary)
                                .font(IWFont.bodyLarge())
                                .foregroundStyle(Color.iwOnSurface)
                                .lineSpacing(3)
                        }
                    }

                    // Comparison to average
                    if review.comparisonToAverage != 0 {
                        let isAbove = review.comparisonToAverage > 0
                        InfoCard(backgroundColor: isAbove ? Color.iwPrimaryFixed.opacity(0.08) : Color.iwSurfaceContainerLow) {
                            HStack(spacing: 10) {
                                Image(systemName: isAbove ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(isAbove ? Color.iwPrimary : Color.iwOutline)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(isAbove
                                         ? "\(review.comparisonToAverage)% above weekly average"
                                         : "\(abs(review.comparisonToAverage))% below weekly average")
                                        .font(IWFont.titleMedium())
                                        .foregroundStyle(Color.iwOnSurface)
                                    Text("compared to your 7-day average")
                                        .font(IWFont.bodyLarge())
                                        .foregroundStyle(Color.iwOutline)
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.iwSurface)
            .navigationTitle("Today's Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Color.iwPrimary)
                }
            }
        }
    }
}

// MARK: - Sub-view

private struct DetailMetric: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
            Text(label)
                .font(IWFont.labelSmall())
                .foregroundStyle(Color.iwOutline)
        }
        .frame(maxWidth: .infinity)
    }
}
