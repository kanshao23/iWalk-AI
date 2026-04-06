import SwiftUI

@Observable
final class JourneyViewModel {
    var activeJourney: VirtualJourney?
    var completedJourneys: [String]
    var todayDistanceKm: Double = 0

    var showMilestonePopup = false
    var reachedMilestone: JourneyMilestone?
    var showJourneySelection = false

    private let journeyKey = "iw_active_journey"
    private let completedKey = "iw_completed_journeys"

    init() {
        if let data = UserDefaults.standard.data(forKey: journeyKey),
           let saved = try? JSONDecoder().decode(VirtualJourney.self, from: data) {
            self.activeJourney = saved
        } else {
            self.activeJourney = JourneyTemplate.nyToLA.createJourney()
        }

        if let data = UserDefaults.standard.data(forKey: completedKey),
           let saved = try? JSONDecoder().decode([String].self, from: data) {
            self.completedJourneys = saved
        } else {
            self.completedJourneys = []
        }
    }

    @discardableResult
    func addWalkDistance(_ km: Double, coinVM: CoinViewModel) -> [JourneyMilestone] {
        guard var journey = activeJourney else { return [] }
        todayDistanceKm += km

        let newMilestones = journey.addDistance(km)
        activeJourney = journey

        for milestone in newMilestones {
            coinVM.earn(
                amount: 20,
                source: .journeyMilestone,
                description: "Reached \(milestone.name)"
            )
        }

        if let last = newMilestones.last {
            reachedMilestone = last
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showMilestonePopup = true
            }
        }

        if journey.isCompleted {
            completedJourneys.append(journey.id)
            saveCompleted()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.showJourneySelection = true
            }
        }

        saveJourney()
        return newMilestones
    }

    func selectJourney(_ template: JourneyTemplate) {
        activeJourney = template.createJourney()
        showJourneySelection = false
        saveJourney()
    }

    var availableJourneys: [JourneyTemplate] {
        JourneyTemplate.allCases.filter { !completedJourneys.contains($0.rawValue) }
    }

    func resetAllData() {
        activeJourney = JourneyTemplate.nyToLA.createJourney()
        completedJourneys = []
        todayDistanceKm = 0
        showMilestonePopup = false
        reachedMilestone = nil
        showJourneySelection = false
        saveJourney()
        saveCompleted()
    }

    private func saveJourney() {
        if let journey = activeJourney,
           let data = try? JSONEncoder().encode(journey) {
            UserDefaults.standard.set(data, forKey: journeyKey)
        }
    }

    private func saveCompleted() {
        if let data = try? JSONEncoder().encode(completedJourneys) {
            UserDefaults.standard.set(data, forKey: completedKey)
        }
    }
}
