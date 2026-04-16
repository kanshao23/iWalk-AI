import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private(set) var syncErrorMessage: String?

    private init() {}

    private enum ReminderID {
        static let dailyWalk = "iw.reminder.daily_walk"
        static let streakRisk = "iw.reminder.streak_risk"
        static let eveningReview = "iw.reminder.evening_review"

        static let all = [dailyWalk, streakRisk, eveningReview]
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            syncErrorMessage = nil
            return true
        case .denied:
            syncErrorMessage = "Push notifications are disabled. Enable in Settings to receive walk reminders."
            return false
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if !granted {
                    syncErrorMessage = "Push notifications are disabled. Enable in Settings to receive walk reminders."
                } else {
                    syncErrorMessage = nil
                }
                return granted
            } catch {
                syncErrorMessage = "Unable to request notification permission: \(error.localizedDescription)"
                return false
            }
        @unknown default:
            syncErrorMessage = "Unknown notification permission status."
            return false
        }
    }

    @discardableResult
    func syncReminders(
        dailyEnabled: Bool,
        streakRiskEnabled: Bool,
        eveningReviewEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ReminderID.all)

        let hasAnyReminderEnabled = dailyEnabled || streakRiskEnabled || eveningReviewEnabled
        guard hasAnyReminderEnabled else {
            syncErrorMessage = nil
            return true
        }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return false }

        var requests: [UNNotificationRequest] = []

        if dailyEnabled {
            requests.append(
                makeRequest(
                    id: ReminderID.dailyWalk,
                    title: "Time to walk",
                    body: "Your daily step goal is waiting. A short walk now keeps momentum.",
                    hour: reminderHour,
                    minute: reminderMinute
                )
            )
        }

        if streakRiskEnabled {
            let streakReminderTime = normalizedStreakReminderTime(
                requestedHour: reminderHour,
                requestedMinute: reminderMinute
            )
            requests.append(
                makeRequest(
                    id: ReminderID.streakRisk,
                    title: "Protect your streak",
                    body: "A quick walk today keeps your streak alive.",
                    hour: streakReminderTime.hour,
                    minute: streakReminderTime.minute
                )
            )
        }

        if eveningReviewEnabled {
            requests.append(
                makeRequest(
                    id: ReminderID.eveningReview,
                    title: "Evening review ready",
                    body: "Check your daily summary and claim your review coins.",
                    hour: 20,
                    minute: 10
                )
            )
        }

        for request in requests {
            do {
                try await center.add(request)
            } catch {
                syncErrorMessage = error.localizedDescription
                return false
            }
        }

        syncErrorMessage = nil

        return true
    }

    private func makeRequest(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = min(max(hour, 0), 23)
        dateComponents.minute = min(max(minute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func normalizedStreakReminderTime(
        requestedHour: Int,
        requestedMinute: Int
    ) -> (hour: Int, minute: Int) {
        let safeHour = min(max(requestedHour, 0), 23)
        let safeMinute = min(max(requestedMinute, 0), 59)
        let requestedTotalMinutes = safeHour * 60 + safeMinute
        let thresholdMinutes = 18 * 60 + 30
        let result = max(requestedTotalMinutes, thresholdMinutes)
        return (result / 60, result % 60)
    }
}
