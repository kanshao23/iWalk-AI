import SwiftUI

struct JourneyCard: View {
    let journey: VirtualJourney

    var body: some View {
        InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.iwSecondary)
                    Text(journey.name)
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwOnSurface)
                    Spacer()
                    Text("\(Int(journey.progress * 100))%")
                        .font(IWFont.labelMedium())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.iwPrimary)
                        .contentTransition(.numericText())
                }

                GeometryReader { geo in
                    let w = geo.size.width

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.iwSurfaceContainerHigh)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [.iwSecondary, .iwSecondaryContainer],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: w * journey.progress, height: 6)

                        ForEach(journey.milestones) { m in
                            let pos = m.distanceFromStartKm / journey.totalDistanceKm
                            Circle()
                                .fill(m.isReached ? Color.iwSecondary : Color.iwSurfaceContainerHighest)
                                .frame(width: 8, height: 8)
                                .offset(x: w * pos - 4)
                        }
                    }
                }
                .frame(height: 10)

                if let next = journey.nextMilestone, let dist = journey.distanceToNextMilestone {
                    HStack(spacing: 6) {
                        Image(systemName: next.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.iwSecondary)
                        Text("Next: \(next.name)")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOnSurface)
                        Spacer()
                        Text(String(format: "%.0f km away", dist))
                            .font(IWFont.labelSmall())
                            .foregroundStyle(Color.iwOutline)
                    }
                } else if journey.isCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.iwPrimary)
                        Text("Journey Complete!")
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwPrimary)
                    }
                }
            }
        }
    }
}
