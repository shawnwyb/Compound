import SwiftUI

// Phase-0 placeholders. Each tab is fleshed out in its own phase:
// Routines → Phase 1, Log → Phase 3, Stats → Phase 4, Profile → Phase 5.

struct LogView: View {
    var body: some View {
        NavigationStack {
            ComingSoon(text: "Your workout history will appear here.")
                .navigationTitle("Log")
        }
    }
}

struct RoutinesView: View {
    var body: some View {
        NavigationStack {
            ComingSoon(text: "Your routines will appear here.")
                .navigationTitle("Routines")
        }
    }
}

struct StatsView: View {
    var body: some View {
        NavigationStack {
            ComingSoon(text: "Your progress and stats will appear here.")
                .navigationTitle("Stats")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ComingSoon(text: "Settings will appear here.")
                .navigationTitle("Profile")
        }
    }
}

private struct ComingSoon: View {
    let text: String
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "hammer.fill",
            description: Text(text)
        )
    }
}
