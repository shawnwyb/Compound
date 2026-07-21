import ActivityKit
import SwiftUI
import WidgetKit

/// The in-progress workout on the Lock Screen, in the Dynamic Island, and as a
/// banner. Deliberately plain for now — Step 4 of the plan does the real layout;
/// this exists so the lifecycle wiring (Step 3) has something to render.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.workoutName)
                    .font(.headline)
                Text(context.state.exerciseName)
                    .font(.subheadline)
                HStack {
                    Text("Set \(context.state.setIndex) of \(context.state.setCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    timer(for: context.state, startedAt: context.attributes.startedAt)
                        .font(.title3)
                        .monospacedDigit()
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.workoutName).font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(for: context.state, startedAt: context.attributes.startedAt)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.state.exerciseName) · Set \(context.state.setIndex) of \(context.state.setCount)")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
            } compactTrailing: {
                timer(for: context.state, startedAt: context.attributes.startedAt)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
            }
        }
    }

    /// Rest counts **down** when resting (matching the in-app rest bar), session
    /// elapsed counts up otherwise. Both are `Date`-driven so iOS ticks them with
    /// the app suspended.
    /// Both use `timerInterval` rather than `Text(_:style:)` — the style variants
    /// render as relative phrases ("1 minute") in this context, not a clock.
    @ViewBuilder
    private func timer(for state: WorkoutActivityAttributes.ContentState, startedAt: Date) -> some View {
        if let restEndsAt = state.restEndsAt {
            Text(timerInterval: Date.now...restEndsAt, countsDown: true)
        } else {
            // Open-ended count-up isn't expressible, so cap at the 8h staleness
            // horizon the controller already uses.
            Text(timerInterval: startedAt...startedAt.addingTimeInterval(8 * 60 * 60), countsDown: false)
        }
    }
}
