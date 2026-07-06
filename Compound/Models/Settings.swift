import Foundation
import SwiftData

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case pounds, kilograms
    var id: String { rawValue }
    var abbreviation: String { self == .pounds ? "lb" : "kg" }
}

enum ThemePreference: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
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

    init(
        units: UnitSystem = .pounds,
        defaultRestSeconds: Int = 90,
        restSoundEnabled: Bool = true,
        restVibrationEnabled: Bool = true,
        theme: ThemePreference = .system
    ) {
        self.units = units
        self.defaultRestSeconds = defaultRestSeconds
        self.restSoundEnabled = restSoundEnabled
        self.restVibrationEnabled = restVibrationEnabled
        self.theme = theme
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
