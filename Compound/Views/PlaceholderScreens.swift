import SwiftUI

// Phase-0 placeholder for tabs not yet built:
// Profile → Phase 5.

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
