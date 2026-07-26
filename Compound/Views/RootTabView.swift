import SwiftUI
import SwiftData

/// The five-tab navigation shell: Log, Routines, Body, Stats, Profile.
///
/// Ordered by how often a tab is opened, not by how important it looks. Body
/// takes a bodyweight every morning and a meal several times a day; Stats is
/// read-only and gets checked about weekly, so it sits after the three tabs
/// that data goes *into* and before the settings nobody visits.
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsRows: [Settings]
    /// The one in-progress workout, owned here so it survives tab switches and
    /// minimize. Injected into the whole tree via `.environment`.
    @State private var active = ActiveWorkout()

    private var settings: Settings {
        settingsRows.first ?? Settings.current(in: context)
    }

    var body: some View {
        // The bar insets each tab's own content rather than the whole `TabView`:
        // insetting the TabView puts it at the bottom of the screen, which on
        // iOS 26 — where the tab bar floats over the content — covers the tab bar
        // completely. (The system's `tabViewBottomAccessory` slot is the other
        // way to do this, but it always reserves its capsule, so it would have to
        // be applied conditionally, and that re-identifies the TabView and pops
        // every tab's navigation stack on minimize.)
        TabView {
            LogView()
                .minimizedWorkoutBar(active)
                .tabItem { Label("Log", systemImage: "calendar") }

            RoutinesView()
                .minimizedWorkoutBar(active)
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }

            BodyView()
                .minimizedWorkoutBar(active)
                .tabItem { Label("Body", systemImage: "figure") }

            StatsView()
                .minimizedWorkoutBar(active)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            ProfileView()
                .minimizedWorkoutBar(active)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .environment(active)
        .fullScreenCover(isPresented: coverPresented, onDismiss: deletePendingWorkout) {
            NavigationStack {
                if let workout = active.workout {
                    WorkoutEditorView(workout: workout, isNew: false)
                        .environment(active)
                }
            }
        }
        .preferredColorScheme(colorScheme(for: settings.theme))
        .onAppear {
            _ = Settings.current(in: context)
            // The timer owns *when* rest ends; the cue depends on Profile
            // settings. Read through the context at fire time rather than
            // capturing `settings` here, which would freeze the preferences as
            // they were when the root appeared.
            active.rest.onCompletion = { [context] in
                let current = Settings.current(in: context)
                RestCompletionAlert.play(
                    sound: current.restSoundEnabled,
                    vibration: current.restVibrationEnabled
                )
            }
            active.restAlertSoundEnabled = settings.restSoundEnabled
            adoptInterruptedWorkout()
        }
        .onChange(of: settings.restSoundEnabled) { _, enabled in
            // Queued alerts are scheduled ahead of time, so the preference has to
            // follow the toggle rather than be read when the rest ends.
            active.restAlertSoundEnabled = enabled
            active.rest.onChange?()
        }
        .onChange(of: scenePhase) { _, phase in
            // A rest that ran out while suspended is settled on return — without
            // a cue, since it finished while nobody was looking.
            if phase == .active {
                active.rest.reconcile()
            } else {
                // Leaving the app is the last moment a force-quit can be seen
                // coming, so the session's typed reps and weights go to disk now
                // rather than riding on autosave.
                try? context.save()
            }
        }
        .onOpenURL { url in
            // The Live Activity has one destination: bring the workout back up.
            if url.scheme == "compound", url.host == "workout", active.isActive {
                active.maximize()
            }
        }
    }

    /// Pick up a workout that survived a crash or force-quit (launch cleanup keeps
    /// only one, and only if sets were logged). It comes back minimized so the
    /// mini-bar surfaces it without hijacking the screen — the user decides
    /// whether to keep going, finish, or discard.
    private func adoptInterruptedWorkout() {
        guard !active.isActive else { return }
        let orphans = (try? context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt == nil })
        )) ?? []
        guard let resumable = WorkoutRecovery.plan(for: orphans).resume else {
            // Nothing survived — clear any Live Activity left over from that run.
            active.discardStaleActivities()
            return
        }
        active.resume(resumable)
    }

    /// Drives the full-screen live workout: shown when active and not minimized.
    /// A system-initiated dismissal collapses to the mini-bar rather than ending
    /// the workout (the cover is otherwise non-interactively dismissable).
    private var coverPresented: Binding<Bool> {
        Binding(
            get: { active.isActive && !active.isMinimized },
            set: { presented in
                if !presented && active.isActive { active.isMinimized = true }
            }
        )
    }

    /// Runs after the live screen has fully dismissed. Discard defers deletion to
    /// here so no view is still rendering the (about-to-be-deleted) set rows.
    private func deletePendingWorkout() {
        guard let doomed = active.pendingDeletion else { return }
        active.pendingDeletion = nil
        context.delete(doomed)
        try? context.save()
    }

    private func colorScheme(for theme: ThemePreference) -> ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    RootTabView()
        .environment(ActiveWorkout())
        .modelContainer(PreviewData.container)
}
