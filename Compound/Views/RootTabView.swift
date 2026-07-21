import SwiftUI
import SwiftData

/// The four-tab navigation shell: Log, Routines, Stats, Profile.
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [Settings]
    /// The one in-progress workout, owned here so it survives tab switches and
    /// minimize. Injected into the whole tree via `.environment`.
    @State private var active = ActiveWorkout()

    private var settings: Settings {
        settingsRows.first ?? Settings.current(in: context)
    }

    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "calendar") }

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            BodyView()
                .tabItem { Label("Body", systemImage: "figure") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .environment(active)
        .safeAreaInset(edge: .bottom) {
            if active.isActive, active.isMinimized, let workout = active.workout {
                WorkoutMiniBar(active: active, workout: workout, settings: settings)
            }
        }
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
            adoptInterruptedWorkout()
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
