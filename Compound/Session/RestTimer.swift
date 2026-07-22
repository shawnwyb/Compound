import Foundation
import Observation

/// The between-set rest timer. Transient UI state — only the elapsed value is
/// ever persisted (to `SetEntry.restSeconds`), never the timer itself.
///
/// The timer owns its own completion: it stops itself at zero and reports it,
/// rather than relying on a visible view to notice. Views used to do that, which
/// meant a rest ending while the app was backgrounded stayed "running" until you
/// came back, and then beeped for something long over.
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var duration: Int = 0

    /// Called whenever `endDate` changes, so the owner can push a Live Activity
    /// update. Set by `ActiveWorkout`; nil in previews and tests.
    var onChange: (() -> Void)?
    /// Called when a rest reaches zero while the app is actually running — the
    /// cue to play sound / haptics. Deliberately not called for a rest that
    /// expired while suspended (see `RestCountdown.shouldAlert`).
    var onCompletion: (() -> Void)?

    @ObservationIgnored private var completionTask: Task<Void, Never>?

    var isActive: Bool { endDate != nil }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        duration = seconds
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
        scheduleCompletion()
        onChange?()
    }

    func stop() {
        guard endDate != nil else { return }
        completionTask?.cancel()
        completionTask = nil
        endDate = nil
        onChange?()
    }

    /// Add or remove time, never pushing the end before the current moment.
    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        endDate = max(end.addingTimeInterval(TimeInterval(seconds)), Date.now)
        scheduleCompletion()
        onChange?()
    }

    func remaining(at now: Date = .now) -> Int {
        guard let end = endDate else { return 0 }
        return RestCountdown.remaining(endDate: end, now: now)
    }

    /// Settle a rest whose end has passed. Called when the timer fires and again
    /// when the app returns to the foreground — the app is suspended in between,
    /// so the fire can arrive arbitrarily late.
    func reconcile(now: Date = .now) {
        guard let end = endDate, end <= now else { return }
        let shouldAlert = RestCountdown.shouldAlert(endDate: end, now: now)
        completionTask?.cancel()
        completionTask = nil
        endDate = nil
        if shouldAlert { onCompletion?() }
        onChange?()
    }

    private func scheduleCompletion() {
        completionTask?.cancel()
        guard let end = endDate else { return }
        completionTask = Task { @MainActor [weak self] in
            let delay = end.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }
}
