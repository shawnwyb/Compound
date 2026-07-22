import Foundation
import UserNotifications

/// Hands the "rest is over" alert to iOS so it arrives even when the app isn't
/// running. The in-app cue (`RestCompletionAlert`) only plays while the app is on
/// screen — pocket the phone between sets and it would otherwise be silent.
///
/// Exactly one alert is ever pending: every rest change re-syncs it, so skipping
/// or ±15-ing a rest can't leave a stale buzz queued up.
final class RestNotifier {

    private static let identifier = "rest-timer-complete"

    private var center: UNUserNotificationCenter { .current() }

    /// Ask once, at the start of a workout rather than at launch, so the prompt
    /// arrives when its purpose is obvious.
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Keep the pending alert in step with the timer: queued for `endDate`, or
    /// cleared when rest stops. A rest that has already run out schedules nothing.
    ///
    /// When the app is in the foreground iOS suppresses delivery by default, so a
    /// rest that ends while you're looking at the screen still only produces the
    /// in-app cue — no double alert.
    func sync(endDate: Date?, sound: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard let endDate else { return }
        let interval = endDate.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "Time for your next set."
        content.sound = sound ? .default : nil

        center.add(
            UNNotificationRequest(
                identifier: Self.identifier,
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
        )
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
