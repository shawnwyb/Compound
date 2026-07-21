import Foundation
import Observation

/// The between-set rest timer. Transient UI state — only the elapsed value is
/// ever persisted (to `SetEntry.restSeconds`), never the timer itself. Held by
/// the live workout screen for now; moves to a root-owned controller in Slice 3.
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var duration: Int = 0

    /// Called whenever `endDate` changes, so the owner can push a Live Activity
    /// update. Set by `ActiveWorkout`; nil in previews and tests.
    var onChange: (() -> Void)?

    var isActive: Bool { endDate != nil }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        duration = seconds
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        onChange?()
    }

    func stop() {
        guard endDate != nil else { return }
        endDate = nil
        onChange?()
    }

    /// Add or remove time, never pushing the end before the current moment.
    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        endDate = max(end.addingTimeInterval(TimeInterval(seconds)), Date.now)
        onChange?()
    }

    func remaining(at now: Date = .now) -> Int {
        guard let end = endDate else { return 0 }
        return RestCountdown.remaining(endDate: end, now: now)
    }
}
