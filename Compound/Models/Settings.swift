import Foundation
import SwiftData

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case pounds, kilograms
    var id: String { rawValue }
    var abbreviation: String { self == .pounds ? "lb" : "kg" }
    var title: String { self == .pounds ? "Pounds (lb)" : "Kilograms (kg)" }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// Single-record app configuration (the Profile / settings page). Fetch-or-create
/// via `Settings.current(in:)`.
@Model
final class Settings {
    var units: UnitSystem
    var defaultRestSeconds: Int
    var restSoundEnabled: Bool
    var restVibrationEnabled: Bool
    var theme: ThemePreference
    /// JSON-encoded backing store for `restPresets`. Stored as `Data`, not
    /// `[Int]`, because SwiftData's array-of-primitive attribute fails to
    /// materialize during store migrations — which breaks *every* later schema
    /// change. Keeping the schema free of `[Int]` attributes avoids that.
    private var restPresetsData: Data = Data("[30,60,90,120,180]".utf8)

    /// User-editable rest-timer presets, in seconds.
    var restPresets: [Int] {
        get { (try? JSONDecoder().decode([Int].self, from: restPresetsData)) ?? [] }
        set { restPresetsData = (try? JSONEncoder().encode(newValue)) ?? restPresetsData }
    }

    init(
        units: UnitSystem = .pounds,
        defaultRestSeconds: Int = 90,
        restSoundEnabled: Bool = true,
        restVibrationEnabled: Bool = true,
        theme: ThemePreference = .system,
        restPresets: [Int] = [30, 60, 90, 120, 180]
    ) {
        self.units = units
        self.defaultRestSeconds = defaultRestSeconds
        self.restSoundEnabled = restSoundEnabled
        self.restVibrationEnabled = restVibrationEnabled
        self.theme = theme
        self.restPresets = restPresets
    }

    /// Returns the singleton settings row, creating it if absent.
    static func current(in context: ModelContext) -> Settings {
        if let existing = try? context.fetch(FetchDescriptor<Settings>()).first {
            return existing
        }
        let created = Settings()
        context.insert(created)
        return created
    }
}
