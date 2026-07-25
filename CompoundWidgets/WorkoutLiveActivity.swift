import ActivityKit
import SwiftUI
import WidgetKit

/// The in-progress workout on the Lock Screen, in the Dynamic Island, and as a
/// banner — one implementation, three presentations.
///
/// The hero number is the **rest countdown** while resting (cyan, matching the
/// in-app rest bar's direction) and the **session elapsed time** otherwise, so the
/// big slot is never blank. Every tap deep-links back and maximizes the workout.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .padding(16)
                .widgetURL(WorkoutActivityLink.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: WorkoutActivityStyle.icon)
                        .font(.caption)
                        .foregroundStyle(WorkoutActivityStyle.accent)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting {
                        elapsed(since: context.attributes.startedAt)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 2) {
                        hero(context)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                        HStack(spacing: 6) {
                            Text(context.state.exerciseName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            setLabel(context.state)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: WorkoutActivityStyle.icon)
                    .foregroundStyle(WorkoutActivityStyle.accent)
            } compactTrailing: {
                hero(context)
                    .font(.caption)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: WorkoutActivityStyle.icon)
                    .foregroundStyle(WorkoutActivityStyle.accent)
            }
            .widgetURL(WorkoutActivityLink.url)
            .keylineTint(WorkoutActivityStyle.accent)
        }
    }

    // MARK: - Lock Screen / banner

    /// Two columns: the timer anchors the leading edge, what you're lifting sits
    /// against the trailing one. A single leading-aligned stack left the right
    /// half of the Lock Screen empty, which reads as content that failed to load.
    ///
    /// `timerInterval` text reserves the width of its widest value and centres
    /// the glyphs inside, so the hero keeps its own column rather than being
    /// aligned against neighbouring text — the reserved box is what's placed, not
    /// the digits.
    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // The header owns its whole row. Nothing shares it, because the one
            // thing that used to — a `Text(timerInterval:)` of elapsed time —
            // reserves the width of its *widest* value ("7:59:59" over the 8h
            // horizon) and cannot compress, so the title was the only flexible
            // thing on the row and got truncated the moment a rest started.
            // Elapsed still runs in the Dynamic Island's trailing region.
            Label(context.attributes.workoutName, systemImage: WorkoutActivityStyle.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WorkoutActivityStyle.accent)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    hero(context)
                        .font(.system(size: 46, weight: .semibold, design: .rounded))
                    // Always present, so the widget keeps one height instead of
                    // growing when a rest starts — and the big number says which
                    // clock it is without anything else on screen to compare it to.
                    Text(context.state.isResting ? "Rest" : "Elapsed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    setLabel(context.state)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // A long exercise name truncates rather than shoving the timer,
                // whose reserved width can't compress.
                .layoutPriority(1)
            }
        }
    }

    // MARK: - Pieces

    private func setLabel(_ state: WorkoutActivityAttributes.ContentState) -> Text {
        Text("Set \(state.setIndex) of \(state.setCount)")
    }

    /// Rest countdown while resting, session elapsed otherwise.
    @ViewBuilder
    private func hero(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        if let restEndsAt = context.state.restEndsAt {
            Text(timerInterval: Date.now...restEndsAt, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(WorkoutActivityStyle.accent)
        } else {
            elapsed(since: context.attributes.startedAt)
                .monospacedDigit()
        }
    }

    /// `timerInterval` rather than `Text(_:style:)` — the style variants render as
    /// relative phrases ("1 minute") here instead of a clock. Count-up needs an end,
    /// so it uses the same 8h horizon as the controller's `staleDate`.
    private func elapsed(since startedAt: Date) -> Text {
        Text(timerInterval: startedAt...startedAt.addingTimeInterval(8 * 60 * 60), countsDown: false)
    }
}

/// Shared look, so the three presentations can't drift apart.
enum WorkoutActivityStyle {
    static let icon = "figure.strengthtraining.traditional"
    static let accent = Color.cyan
}

/// Deep link back into the app. One destination: maximize the live workout.
enum WorkoutActivityLink {
    static let url = URL(string: "compound://workout")
}

// MARK: - Previews

extension WorkoutActivityAttributes {
    fileprivate static var preview: WorkoutActivityAttributes {
        WorkoutActivityAttributes(workoutName: "Full Body A", startedAt: .now.addingTimeInterval(-1_500))
    }
}

extension WorkoutActivityAttributes.ContentState {
    fileprivate static var lifting: Self {
        .init(exerciseName: "Bench Press", setIndex: 2, setCount: 3, restEndsAt: nil)
    }

    fileprivate static var resting: Self {
        .init(exerciseName: "Bench Press", setIndex: 2, setCount: 3, restEndsAt: .now.addingTimeInterval(90))
    }
}

#Preview("Lock Screen", as: .content, using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.lifting
    WorkoutActivityAttributes.ContentState.resting
}

#Preview("Dynamic Island (expanded)", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes.preview) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState.lifting
    WorkoutActivityAttributes.ContentState.resting
}
