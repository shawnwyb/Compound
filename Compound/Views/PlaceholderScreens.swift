import SwiftUI

// Phase-0 placeholders for tabs not yet built:
// Stats → Phase 4, Profile → Phase 5.

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
