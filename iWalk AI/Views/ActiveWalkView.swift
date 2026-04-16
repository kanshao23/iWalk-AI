import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Location Manager for Walk

final class WalkLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isTracking = false
    @Published private(set) var hasLocationPermission = false
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var currentCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()
    private var lastRouteLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
    }

    func startTracking() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            hasLocationPermission = false
            isTracking = false
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            isTracking = false
            hasLocationPermission = false
        case .authorizedWhenInUse, .authorizedAlways:
            hasLocationPermission = true
            isTracking = true
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Reject readings with poor accuracy (> 20m) — common at GPS startup
        guard let location = locations.last,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 20 else { return }

        DispatchQueue.main.async {
            self.currentCoordinate = location.coordinate

            if let lastRouteLocation = self.lastRouteLocation, location.distance(from: lastRouteLocation) < 5 {
                return
            }

            self.routeCoordinates.append(location.coordinate)
            self.lastRouteLocation = location
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            hasLocationPermission = true
            isTracking = true
            manager.startUpdatingLocation()
        } else {
            hasLocationPermission = false
            isTracking = false
            if status == .denied || status == .restricted {
                manager.stopUpdatingLocation()
            }
        }
    }
}

// MARK: - Container

struct ActiveWalkContainerView: View {
    @State var vm: ActiveWalkViewModel
    let onComplete: (WalkSession) -> Void

    var body: some View {
        ZStack {
            // Animated gradient background
            WalkBackground(progress: vm.gradientProgress, isPaused: vm.isPaused)
                .ignoresSafeArea()

            switch vm.phase {
            case .countdown(let count):
                CountdownOverlay(count: count)
            case .active, .paused:
                ActiveWalkContent(vm: vm)
            case .summary(let session):
                WalkSummaryContent(session: session, onDone: { onComplete(session) })
            }

            // Milestone toast
            if vm.showMilestoneToast, let milestone = vm.currentMilestone {
                VStack {
                    MilestoneToast(milestone: milestone)
                        .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { vm.startCountdown() }
        .statusBarHidden()
    }
}

// MARK: - Countdown Overlay

private struct CountdownOverlay: View {
    let count: Int

    var body: some View {
        ZStack {
            Text(count > 0 ? "\(count)" : "GO!")
                .font(count > 0 ? IWFont.displayLarge() : .system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(count > 0 ? .white : Color.iwPrimaryFixed)
                .scaleEffect(1.0)
                .id(count) // Force re-render for each number
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 2.5).combined(with: .opacity),
                        removal: .scale(scale: 0.3).combined(with: .opacity)
                    )
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Active Walk Content

private struct ActiveWalkContent: View {
    @Bindable var vm: ActiveWalkViewModel
    @StateObject private var locationManager = WalkLocationManager()
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen map centered on user
            Map(position: $mapPosition) {
                if locationManager.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: locationManager.routeCoordinates)
                        .stroke(Color.iwPrimary, lineWidth: 4)
                }
                if let current = locationManager.currentCoordinate {
                    Annotation("Current location", coordinate: current) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.iwPrimary)
                            .background(Circle().fill(.white).frame(width: 22, height: 22))
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            .onAppear {
                locationManager.startTracking()
            }
            .onDisappear {
                locationManager.stopTracking()
            }
            .onReceive(locationManager.$routeCoordinates) { coordinates in
                vm.updateRouteCoordinates(coordinates)
            }
            .overlay(alignment: .top) {
                if !locationManager.hasLocationPermission {
                    Text("Enable location permission to draw your route in real-time.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 96)
                        .padding(.horizontal, 16)
                }
            }

            // Bottom stats panel
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Drag handle
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)

                    // Elapsed time — prominent, on dark background for readability
                    HStack(spacing: 10) {
                        Circle()
                            .fill(vm.isPaused ? .white.opacity(0.3) : Color.iwPrimary)
                            .frame(width: 10, height: 10)
                            .opacity(vm.isPaused ? 1 : 1)
                        Text(vm.elapsedFormatted)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        if !vm.usesRealPedometer {
                            Text("SIM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    // Main stats row: steps + ring + distance
                    HStack(spacing: 0) {
                        // Session steps
                        VStack(spacing: 2) {
                            Text("+\(vm.sessionSteps.formatted())")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.iwPrimaryFixed)
                                .contentTransition(.numericText())
                            Text("\(vm.totalSteps.formatted()) total")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)

                        // Compact progress ring — percentage only
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.15), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: vm.goalProgress)
                                .stroke(
                                    AngularGradient(
                                        colors: [.iwPrimary, .iwPrimaryContainer, .iwPrimaryFixed],
                                        center: .center,
                                        startAngle: .degrees(0),
                                        endAngle: .degrees(360 * max(vm.goalProgress, 0.01))
                                    ),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(Int(vm.goalProgress * 100))%")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                                Text("Goal")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .frame(width: 90, height: 90)

                        // Distance
                        VStack(spacing: 2) {
                            Text(String(format: "%.2f", vm.sessionDistanceKm))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                            Text("km")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Secondary stats row
                    HStack(spacing: 12) {
                        CompactStatPill(icon: "speedometer", value: vm.paceFormatted, label: "min/km", iconColor: .iwSecondary)
                        CompactStatPill(icon: "flame.fill", value: "\(vm.sessionCalories)", label: "kcal", iconColor: .iwTertiaryContainer)
                        // Heart rate only shown if real data available (Apple Watch)
                        if vm.hasRealHeartRate {
                            CompactStatPill(icon: "heart.fill", value: "\(vm.currentHeartRate)", label: vm.heartRateZone, iconColor: vm.heartRateZoneColor)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Bottom Buttons
                    HStack(spacing: 16) {
                        Button {
                            if vm.isPaused { vm.resume() } else { vm.pause() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: vm.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(vm.isPaused ? "Resume" : "Pause")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                        }

                        Button {
                            vm.endWalk()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("End Walk")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.iwError)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(hex: 0x1A1A2E).opacity(0.95))
                        .ignoresSafeArea(edges: .bottom)
                )
            }
        }
    }
}

// MARK: - Compact Stat Pill

private struct CompactStatPill: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Milestone Toast

private struct MilestoneToast: View {
    let milestone: WalkMilestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.icon)
                .font(.system(size: 24))
                .foregroundStyle(milestone.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(IWFont.titleMedium())
                    .foregroundStyle(.white)
                Text("Keep going!")
                    .font(IWFont.labelMedium())
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Walk Summary

private struct WalkSummaryContent: View {
    let session: WalkSession
    let onDone: () -> Void

    @State private var ringAnimated = false
    @State private var statsAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.iwPrimaryFixed)
                    Text("Walk Complete!")
                        .font(IWFont.headlineLarge())
                        .foregroundStyle(.white)
                }

                // Before vs After Ring
                ZStack {
                    // Before (dimmed)
                    StepProgressRing(
                        currentSteps: session.stepsBeforeWalk,
                        goalSteps: session.dailyGoal,
                        lineWidth: 10,
                        animatedProgress: session.goalProgressBefore,
                        onDarkBackground: true
                    )
                    .opacity(0.3)
                    .frame(width: 160, height: 160)

                    // After (bright)
                    StepProgressRing(
                        currentSteps: session.totalSteps,
                        goalSteps: session.dailyGoal,
                        lineWidth: 12,
                        animatedProgress: ringAnimated ? session.goalProgressAfter : session.goalProgressBefore,
                        onDarkBackground: true
                    )
                    .frame(width: 160, height: 160)
                }

                // Route map (only if GPS was tracked)
                if let points = session.routePoints, points.count >= 2 {
                    let coords = points.map(\.clLocation)
                    Map(initialPosition: .region(routeRegion(for: coords))) {
                        MapPolyline(coordinates: coords)
                            .stroke(Color.iwPrimary, lineWidth: 4)
                        if let first = coords.first {
                            Annotation("Start", coordinate: first) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                        if let last = coords.last {
                            Annotation("End", coordinate: last) {
                                Circle()
                                    .fill(Color.iwError)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .mapControlVisibility(.hidden)
                    .allowsHitTesting(false)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 20)
                }

                // Stats Card
                VStack(spacing: 16) {
                    SummaryRow(icon: "clock.fill", label: "Duration", value: session.elapsedFormatted, color: .iwSecondary)
                    SummaryRow(icon: "figure.walk", label: "Steps", value: session.steps.formatted(), color: .iwPrimary)
                    SummaryRow(icon: "mappin.and.ellipse", label: "Distance", value: String(format: "%.2f km", session.distanceKm), color: .iwPrimaryContainer)
                    SummaryRow(icon: "flame.fill", label: "Calories", value: "\(session.calories) kcal", color: .iwTertiaryContainer)
                    SummaryRow(icon: "speedometer", label: "Avg Pace", value: "\(session.paceFormatted) min/km", color: .iwSecondaryFixedDim)
                    if session.averageHeartRate > 0 {
                        SummaryRow(icon: "heart.fill", label: "Avg Heart Rate", value: "\(session.averageHeartRate) bpm", color: .iwError)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .opacity(statsAppeared ? 1 : 0)
                .offset(y: statsAppeared ? 0 : 20)

                // Milestone Badge
                if let milestone = session.highestMilestone {
                    HStack(spacing: 12) {
                        Image(systemName: milestone.icon)
                            .font(.system(size: 28))
                            .foregroundStyle(milestone.color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.title)
                                .font(IWFont.titleMedium())
                                .foregroundStyle(.white)
                            Text("You reached \(Int(milestone.threshold * 100))% of your daily goal!")
                                .font(IWFont.bodyMedium())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(20)
                    .background(milestone.color.opacity(0.2))
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                }

                // Done Button
                Button(action: onDone) {
                    Text("Done")
                        .font(IWFont.labelLarge())
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.iwPrimaryGradient)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                ringAnimated = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                statsAppeared = true
            }
        }
    }
}

private struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(IWFont.bodyMedium())
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(IWFont.titleMedium())
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }
}

// MARK: - Animated Background

// MARK: - Route region helper

private func routeRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    let lats = coordinates.map(\.latitude)
    let lons = coordinates.map(\.longitude)
    guard let minLat = lats.min(), let maxLat = lats.max(),
          let minLon = lons.min(), let maxLon = lons.max() else {
        return MKCoordinateRegion()
    }
    let center = CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
    )
    let span = MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.5, 0.005),
        longitudeDelta: max((maxLon - minLon) * 1.5, 0.005)
    )
    return MKCoordinateRegion(center: center, span: span)
}

// MARK: - Animated Background

private struct WalkBackground: View {
    let progress: Double
    let isPaused: Bool

    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x1A1A2E),
                Color(hex: 0x16213E),
                Color(hex: 0x0F0F1A),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
