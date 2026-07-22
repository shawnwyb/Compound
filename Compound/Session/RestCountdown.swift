import Foundation

/// Countdown math for the rest timer. Pure — unit tested.
enum RestCountdown {

    /// Whole seconds remaining until `endDate`, rounded up, never negative.
    static func remaining(endDate: Date, now: Date) -> Int {
        max(0, Int(endDate.timeIntervalSince(now).rounded(.up)))
    }

    /// How long after a rest ends the completion cue is still worth playing.
    /// The app can't run while suspended, so a rest that expired in the
    /// background is only noticed on return — beeping then would be a cue for
    /// something that finished minutes ago.
    static let alertGrace: TimeInterval = 3

    /// Whether the completion cue should still fire for a rest that ended at
    /// `endDate`. False when it ended before we were looking, or in the future.
    static func shouldAlert(endDate: Date, now: Date, grace: TimeInterval = alertGrace) -> Bool {
        let late = now.timeIntervalSince(endDate)
        return late >= 0 && late <= grace
    }
}
