import SwiftUI
import SwiftData

/// The four-tab navigation shell: Log, Routines, Stats, Profile.
struct RootTabView: View {
    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "calendar") }

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
