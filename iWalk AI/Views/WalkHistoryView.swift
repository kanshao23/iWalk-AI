import SwiftUI

struct WalkHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    private let history: [WalkSession]

    init() {
        self.history = ActiveWalkViewModel.loadHistory()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.iwSurface.ignoresSafeArea()
                if history.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Walk History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(IWFont.labelLarge())
                        .foregroundStyle(Color.iwPrimary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.iwOutlineVariant)
            Text("No walks yet")
                .font(IWFont.titleMedium())
                .foregroundStyle(Color.iwOnSurface)
            Text("Complete your first walk to see it here.")
                .font(IWFont.bodyMedium())
                .foregroundStyle(Color.iwOutline)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedHistory, id: \.key) { group in
                    Section {
                        ForEach(group.sessions, id: \.id) { session in
                            SessionRow(session: session)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                    } header: {
                        Text(group.key)
                            .font(IWFont.labelLarge())
                            .foregroundStyle(Color.iwOutline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.iwSurface)
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var groupedHistory: [(key: String, sessions: [WalkSession])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let grouped = Dictionary(grouping: history) { session in
            formatter.string(from: session.startTime)
        }
        return grouped
            .sorted { a, b in
                let aDate = history.first { formatter.string(from: $0.startTime) == a.key }?.startTime ?? .distantPast
                let bDate = history.first { formatter.string(from: $0.startTime) == b.key }?.startTime ?? .distantPast
                return aDate > bDate
            }
            .map { (key: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: WalkSession
    @State private var isExpanded = false

    private var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: session.startTime)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.iwPrimaryContainer)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "figure.walk")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.iwPrimary)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(session.steps.formatted()) steps")
                            .font(IWFont.labelLarge())
                            .foregroundStyle(Color.iwOnSurface)
                        Text(timeString)
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(session.formattedDuration)
                            .font(IWFont.labelLarge())
                            .foregroundStyle(Color.iwOnSurface)
                        Text(String(format: "%.2f km", session.distanceKm))
                            .font(IWFont.labelMedium())
                            .foregroundStyle(Color.iwOutline)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.iwOutlineVariant)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 0) {
                    detailItem(icon: "flame.fill", value: "\(session.calories)", label: "kcal")
                    detailItem(icon: "speedometer", value: session.paceFormatted, label: "min/km")
                    if session.averageHeartRate > 0 {
                        detailItem(icon: "heart.fill", value: "\(session.averageHeartRate)", label: "bpm")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color.iwSurfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.iwPrimary)
            Text(value)
                .font(IWFont.labelLarge())
                .foregroundStyle(Color.iwOnSurface)
            Text(label)
                .font(IWFont.labelSmall())
                .foregroundStyle(Color.iwOutline)
        }
        .frame(maxWidth: .infinity)
    }
}
