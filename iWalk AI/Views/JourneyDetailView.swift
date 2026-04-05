import SwiftUI
import MapKit

struct JourneyDetailView: View {
    let journey: VirtualJourney
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Map
                    Map {
                        MapPolyline(coordinates: journey.milestones.map(\.coordinate.clLocation))
                            .stroke(Color.iwSecondary, lineWidth: 3)

                        ForEach(journey.milestones) { milestone in
                            Annotation(milestone.name, coordinate: milestone.coordinate.clLocation) {
                                Circle()
                                    .fill(milestone.isReached ? Color.iwPrimary : Color.iwSurfaceContainerHigh)
                                    .frame(width: 16, height: 16)
                                    .overlay(
                                        Image(systemName: milestone.isReached ? "checkmark" : "")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                            }
                        }

                        if let current = currentPosition {
                            Annotation("You", coordinate: current) {
                                Image(systemName: "figure.walk.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.iwPrimary)
                                    .background(Circle().fill(.white).frame(width: 20, height: 20))
                            }
                        }
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Progress summary
                    InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                        HStack(spacing: 20) {
                            VStack(spacing: 4) {
                                Text(String(format: "%.0f", journey.distanceCoveredKm))
                                    .font(IWFont.titleLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                Text("km walked")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            VStack(spacing: 4) {
                                Text("\(Int(journey.progress * 100))%")
                                    .font(IWFont.titleLarge())
                                    .foregroundStyle(Color.iwPrimary)
                                Text("complete")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                            VStack(spacing: 4) {
                                Text("\(journey.reachedMilestones.count)/\(journey.milestones.count)")
                                    .font(IWFont.titleLarge())
                                    .foregroundStyle(Color.iwOnSurface)
                                Text("cities")
                                    .font(IWFont.labelSmall())
                                    .foregroundStyle(Color.iwOutline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Milestones list
                    VStack(spacing: 12) {
                        SectionHeader("Milestones")

                        ForEach(journey.milestones) { milestone in
                            InfoCard(backgroundColor: .iwSurfaceContainerLowest) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(milestone.isReached ? Color.iwPrimary.opacity(0.15) : Color.iwSurfaceContainerHigh)
                                            .frame(width: 44, height: 44)
                                        Image(systemName: milestone.icon)
                                            .font(.system(size: 18))
                                            .foregroundStyle(milestone.isReached ? Color.iwPrimary : Color.iwOutline)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(milestone.name)
                                                .font(IWFont.labelLarge())
                                                .foregroundStyle(Color.iwOnSurface)
                                            Spacer()
                                            Text(String(format: "%.0f km", milestone.distanceFromStartKm))
                                                .font(IWFont.labelSmall())
                                                .foregroundStyle(Color.iwOutline)
                                        }

                                        if milestone.isReached {
                                            Text(milestone.funFact)
                                                .font(IWFont.labelSmall())
                                                .foregroundStyle(Color.iwOutline)
                                                .lineSpacing(2)
                                            if let date = milestone.reachedDate {
                                                Text("Reached \(date.formatted(.dateTime.month().day()))")
                                                    .font(IWFont.labelSmall())
                                                    .foregroundStyle(Color.iwPrimary)
                                            }
                                        } else {
                                            let remaining = max(milestone.distanceFromStartKm - journey.distanceCoveredKm, 0)
                                            Text(String(format: "%.0f km remaining", remaining))
                                                .font(IWFont.labelSmall())
                                                .foregroundStyle(Color.iwOutlineVariant)
                                        }
                                    }
                                }
                            }
                            .opacity(milestone.isReached ? 1.0 : 0.7)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.iwSurface)
            .navigationTitle(journey.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }

    private var currentPosition: CLLocationCoordinate2D? {
        let milestones = journey.milestones.sorted { $0.distanceFromStartKm < $1.distanceFromStartKm }

        var prev: JourneyMilestone?
        for m in milestones {
            if journey.distanceCoveredKm < m.distanceFromStartKm {
                if let p = prev {
                    let segDist = m.distanceFromStartKm - p.distanceFromStartKm
                    guard segDist > 0 else { return p.coordinate.clLocation }
                    let progress = (journey.distanceCoveredKm - p.distanceFromStartKm) / segDist
                    let lat = p.coordinate.latitude + (m.coordinate.latitude - p.coordinate.latitude) * progress
                    let lon = p.coordinate.longitude + (m.coordinate.longitude - p.coordinate.longitude) * progress
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                } else {
                    return milestones.first?.coordinate.clLocation
                }
            }
            prev = m
        }
        return milestones.last?.coordinate.clLocation
    }
}
