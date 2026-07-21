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

    @ViewBuilder
    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(context.attributes.workoutName, systemImage: WorkoutActivityStyle.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WorkoutActivityStyle.accent)
                    .lineLimit(1)
                Spacer()
                // Only shown while resting — otherwise elapsed *is* the hero below.
                if context.state.isResting {
                    elapsed(since: context.attributes.startedAt)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // The hero gets its own line: `timerInterval` text reserves a fixed
            // width for its widest value and centres the glyphs inside it, so it
            // can't be reliably aligned against neighbouring text on one row.
            hero(context)
                .font(.system(size: 46, weight: .semibold, design: .rounded))

            HStack(spacing: 6) {
                Text(context.state.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                setLabel(context.state)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
