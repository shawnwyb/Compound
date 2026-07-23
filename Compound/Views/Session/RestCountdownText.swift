import SwiftUI

/// The running rest countdown, in a view of its own so the one-second tick
/// redraws a single `Text` and nothing else. Wrapping a whole bar in the
/// `TimelineView` instead makes SwiftUI rebuild its buttons, icons and layout
/// every second for one changed digit.
///
/// Only ever placed where a rest is actually running: an idle `TimelineView`
/// still wakes the view tree once a second to render the same "0:00".
struct RestCountdownText: View {
    let rest: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(TimeFormat.clock(rest.remaining(at: context.date)))
                .monospacedDigit()
        }
    }
}

/// Time elapsed since `since`, ticking once a second — the session clock shown
/// on the live screen, the mini-bar, and the Log's in-progress card. Isolated
/// for the same reason as `RestCountdownText`.
///
/// Elapsed time is always derived from the start timestamp rather than counted
/// up by a running loop, so it stays correct across suspension: iOS stops
/// giving the app CPU the moment the screen locks, and a counter would simply
/// miss those seconds.
struct ElapsedTimeText: View {
    let since: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(TimeFormat.clock(max(0, Int(context.date.timeIntervalSince(since)))))
                .monospacedDigit()
        }
    }
}
