import Foundation

// MARK: - Plain-value stats model
// Pure value types so StatsCalculator is testable without SwiftData/SwiftUI.

/// One set as recorded for stats (volume / PRs only count `completed` sets).
struct StatsSet: Equatable {
    let reps: Int
    let weight: Double
    let completed: Bool
}

/// One exercise performance within a workout, with enough identity for grouping
/// and personal records.
struct StatsExercise: Equatable {
    let exerciseID: UUID
    let exerciseName: String
    let groupID: UUID?
    let groupName: String
    let sets: [StatsSet]
}

/// A performed workout reduced to what stats need.
struct StatsWorkout: Equatable {
    let id: UUID
    let date: Date
    let exercises: [StatsExercise]
}

/// Aggregate totals for the Stats header.
struct StatsTotals: Equatable {
    let workoutCount: Int
    let totalVolume: Double
    let completedSetCount: Int
    let trainingDayCount: Int
}

/// Current / longest streak plus recent frequency.
struct StreakStats: Equatable {
    let current: Int
    let longest: Int
    /// Distinct calendar days with a workout in the last 7 days (including today).
    let daysLast7: Int
    /// Distinct calendar days with a workout in the last 30 days (including today).
    let daysLast30: Int
}

// MARK: - Progression explorer

/// One point in a progression line chart — a session (for an exercise) or a
/// logged day (for a body metric).
struct SeriesPoint: Equatable, Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

/// Which numeric readout of an exercise's completed sets to plot over time.
enum ExerciseMetric: String, CaseIterable, Identifiable {
    /// Heaviest weight lifted in the session (the default).
    case topSetWeight
    /// Best Epley estimated 1RM across the session's sets.
    case estimatedOneRepMax
    /// Σ (reps × weight) over the session's completed sets.
    case volume

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topSetWeight: "Top set"
        case .estimatedOneRepMax: "Est. 1RM"
        case .volume: "Volume"
        }
    }
}

/// A body metric logged per calendar day on the Body tab.
enum BodyMetric: String, CaseIterable, Identifiable {
    case bodyWeight
    case calories
    case protein

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bodyWeight: "Bodyweight"
        case .calories: "Calories"
        case .protein: "Protein"
        }
    }
}

/// A day of body data reduced to plain values, so body series are testable
/// without SwiftData.
struct BodyPoint: Equatable {
    let date: Date
    let bodyWeight: Double?
    let calories: Int?
    let protein: Int?
}

/// An exercise that has appeared in history, for the metric picker.
struct TrackedExercise: Equatable, Identifiable {
    let id: UUID
    let name: String
    let lastPerformed: Date
}

/// Latest / best / net change across a series' visible range.
struct SeriesSummary: Equatable {
    let latest: Double?
    let best: Double?
    /// `latest − earliest` over the visible points; nil when empty.
    let change: Double?
    let pointCount: Int
}

/// Trailing-window options for the progression chart.
enum StatsRange: String, CaseIterable, Identifiable {
    case month1
    case month3
    case month6
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month1: "1M"
        case .month3: "3M"
        case .month6: "6M"
        case .all: "All"
        }
    }

    /// Length of the trailing window in days, or nil for all-time.
    var days: Int? {
        switch self {
        case .month1: 30
        case .month3: 90
        case .month6: 180
        case .all: nil
        }
    }
}
