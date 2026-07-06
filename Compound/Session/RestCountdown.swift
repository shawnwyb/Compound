import Foundation

/// Countdown math for the rest timer. Pure — unit tested.
enum RestCountdown {

    /// Whole seconds remaining until `endDate`, rounded up, never negative.
    static func remaining(endDate: Date, now: Date) -> Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }
}
