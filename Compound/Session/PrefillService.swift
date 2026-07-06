import Foundation

// MARK: - Plain-value history model
// Pure value types so the prefill logic is testable without SwiftData/SwiftUI.

/// A single set as recorded in a past workout.
struct HistoricalSet: Equatable {
    let setNumber: Int
    let reps: Int
    let weight: Double
    let completed: Bool
}

/// One exercise's performance within a past workout.
struct HistoricalExercise: Equatable {
    let exerciseID: UUID
    let sets: [HistoricalSet]
}

/// A past workout, reduced to what prefill needs.
struct HistoricalWorkout: Equatable {
    let date: Date
    let exercises: [HistoricalExercise]
}

/// Remembered values used to seed one set when starting a workout.
struct PrefilledSet: Equatable {
    let reps: Int
    let weight: Double
}

/// Finds the values to pre-fill a new session with, from prior history.
enum PrefillService {

    /// The set values from the most recent workout in which `exerciseID` was
    /// actually worked — i.e. its most recent performance where at least one set
    /// has real data (any reps or weight). All of that performance's sets are
    /// returned (in set order), so edits to weight/reps and added/deleted sets
    /// carry forward regardless of whether the completion toggle was tapped.
    /// Performances left entirely blank are skipped in favor of older, real data.
    /// Returns an empty array when there is no qualifying history.
    static func lastValues(for exerciseID: UUID, in history: [HistoricalWorkout]) -> [PrefilledSet] {
        for workout in history.sorted(by: { $0.date > $1.date }) {
            guard let performed = workout.exercises.first(where: { $0.exerciseID == exerciseID }) else {
                continue
            }
            let hasData = performed.sets.contains { $0.reps > 0 || $0.weight > 0 }
            if hasData {
                return performed.sets
                    .sorted { $0.setNumber < $1.setNumber }
                    .map { PrefilledSet(reps: $0.reps, weight: $0.weight) }
            }
        }
        return []
    }
}
