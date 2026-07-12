import SwiftUI
import SwiftData

/// The four-tab navigation shell: Log, Routines, Stats, Profile.
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [Settings]

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

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .preferredColorScheme(colorScheme(for: settings.theme))
        .onAppear { _ = Settings.current(in: context) }
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
        .modelContainer(PreviewData.container)
}
