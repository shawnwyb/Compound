import SwiftUI

/// The persistent bar shown above the tab bar while a workout is minimized.
/// Tapping the body re-opens (maximizes) the workout. When a rest timer is
/// running it swaps to a stop / countdown / dismiss layout; the ✕ only hides the
/// rest timer — it never ends the workout.
struct WorkoutMiniBar: View {
    @Bindable var active: ActiveWorkout
    let workout: Workout

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { active.maximize() }
    }

    /// A floating capsule on iOS 26, matching the shape of the tab bar it sits
    /// above; the edge-to-edge bar it has always been on older systems, where the
    /// tab bar is an opaque slab.
    @ViewBuilder private var content: some View {
        if #available(iOS 26.0, *) {
            bar
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        } else {
            bar
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
        }
    }

    private var bar: some View {
        HStack(spacing: 12) {
            if active.rest.isActive {
                restContent
            } else {
                idleContent
            }
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Layouts

    @ViewBuilder private var restContent: some View {
        Button { active.rest.stop() } label: {
            Image(systemName: "stop.circle.fill")
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop rest timer")

        RestCountdownText(rest: active.rest)
            .font(.title3)
            .fontWeight(.semibold)

        Spacer()

        Button { active.rest.stop() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss rest timer")
    }

    @ViewBuilder private var idleContent: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .foregroundStyle(.tint)
        Text(workout.routineName.isEmpty ? "Workout" : workout.routineName)
            .fontWeight(.semibold)
            .lineLimit(1)

        Spacer()

        ElapsedTimeText(since: workout.startedAt)
            .foregroundStyle(.secondary)
        // A real button, not just decoration on the bar's tap gesture, so
        // VoiceOver has something to land on and activate.
        Button { active.maximize() } label: {
            Image(systemName: "chevron.up")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reopen workout")
    }
}

extension View {
    /// Rides the minimized workout above this tab's content, inside the tab's own
    /// safe area so it never covers the tab bar. Contributes no height — and no
    /// chrome — when no workout is minimized.
    func minimizedWorkoutBar(_ active: ActiveWorkout) -> some View {
        safeAreaInset(edge: .bottom) {
            if active.isActive, active.isMinimized, let workout = active.workout {
                WorkoutMiniBar(active: active, workout: workout)
            }
        }
    }
}
