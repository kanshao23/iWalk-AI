import Foundation
import HealthKit

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()

    var isAuthorized = false
    var authorizationError: String?

    private let store = HKHealthStore()

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) { types.insert(distance) }
        if let calories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(calories) }
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) { types.insert(heartRate) }
        return types
    }()

    private init() {
        // HealthKit read authorization can't be checked directly.
        // We check if we've previously requested (stored in UserDefaults).
        if HKHealthStore.isHealthDataAvailable() {
            isAuthorized = UserDefaults.standard.bool(forKey: "iw_healthkit_authorized")
        }
    }

    // MARK: - Authorization

    /// Request HealthKit authorization. Call when user taps "Start Walking".
    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationError = "Health data not available on this device."
            return false
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // We can't directly check read authorization, but assume success after request
            _ = await fetchTodaySteps()
            isAuthorized = true
            UserDefaults.standard.set(true, forKey: "iw_healthkit_authorized")
            return true
        } catch {
            authorizationError = error.localizedDescription
            return false
        }
    }

    // MARK: - Today's Steps

    func fetchTodaySteps() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            store.execute(query)
        }
    }

    // MARK: - Today's Distance (km)

    func fetchTodayDistance() async -> Double {
        guard let distType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: distType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let meters = result?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: meters / 1000.0)
            }
            store.execute(query)
        }
    }

    // MARK: - Today's Calories

    func fetchTodayCalories() async -> Int {
        guard let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                let cal = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: Int(cal))
            }
            store.execute(query)
        }
    }

    // MARK: - Weekly Steps (last 7 days)

    func fetchWeeklySteps() async -> [DailyStats] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        let endDate = Date.now
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) else { return [] }

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var daily: [DailyStats] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    daily.append(DailyStats(
                        date: stats.startDate,
                        steps: steps,
                        calories: steps / 20,
                        distanceKm: Double(steps) / 1400.0,
                        activeMinutes: steps / 200,
                        heartRate: nil
                    ))
                }
                continuation.resume(returning: daily)
            }
            store.execute(query)
        }
    }

    // MARK: - Monthly Steps (for habits calendar)

    func fetchMonthlySteps(year: Int, month: Int) async -> [HabitDay] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [] }
        let calendar = Calendar.current
        guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let endDate = calendar.date(byAdding: .month, value: 1, to: startDate) else { return [] }

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate),
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                var days: [HabitDay] = []
                let clampedEnd = min(endDate, Date.now)
                results?.enumerateStatistics(from: startDate, to: clampedEnd) { stats, _ in
                    let steps = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    let completion: HabitCompletion = steps >= 10_000 ? .complete : (steps >= 3_000 ? .partial : .none)
                    days.append(HabitDay(date: stats.startDate, completion: completion, steps: steps))
                }
                continuation.resume(returning: days)
            }
            store.execute(query)
        }
    }

    // MARK: - Latest Heart Rate

    func fetchLatestHeartRate() async -> Int? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }

        return await withCheckedContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }
}
