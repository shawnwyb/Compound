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

/// Volume + set count for one muscle group.
struct GroupVolume: Equatable, Identifiable {
    let groupID: UUID?
    let groupName: String
    let volume: Double
    let setCount: Int

    var id: String { groupID?.uuidString ?? groupName }
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

/// Best lift for one exercise across history.
struct PersonalRecord: Equatable, Identifiable {
    let exerciseID: UUID
    let exerciseName: String
    let bestWeight: Double
    let estimatedOneRepMax: Double
    /// Date of the workout that produced `bestWeight`.
    let bestWeightDate: Date

    var id: UUID { exerciseID }
}

/// Workouts (session count) on one calendar day — for frequency charts.
struct DailyWorkoutCount: Equatable, Identifiable {
    let day: Date
    let count: Int

    var id: Date { day }
}

/// Completed-set volume on one calendar day — for volume charts.
struct DailyVolume: Equatable, Identifiable {
    let day: Date
    let volume: Double

    var id: Date { day }
}
