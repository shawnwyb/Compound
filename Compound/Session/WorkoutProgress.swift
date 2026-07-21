import Foundation

/// What the Live Activity needs to say about where you are in the session:
/// which exercise, and which set of how many. Kept as a protocol pair so the
/// rule is testable without a `ModelContainer` (same shape as `WorkoutRecovery`).
protocol ProgressSet {
    var completed: Bool { get }
}

protocol ProgressExercise {
    associatedtype Sets: ProgressSet
    var exerciseName: String { get }
    var progressSets: [Sets] { get }
}

extension SetEntry: ProgressSet {}

extension WorkoutExercise: ProgressExercise {
    var progressSets: [SetEntry] { orderedSets }
}

/// Derives "current exercise / Set N of M" from a workout in progress.
enum WorkoutProgress {

    struct Position: Equatable {
        var exerciseName: String
        /// 1-based position of the current set within its exercise.
        var setIndex: Int
        /// Sets in that exercise.
        var setCount: Int
        /// Every set in the whole session is done — the current position is the
        /// last set rather than a next one.
        var isComplete: Bool
    }

    /// The first exercise still holding an incomplete set, and that set. Exercises
    /// with no sets are skipped — they can't be "current". When everything is
    /// complete the last non-empty exercise is reported with `isComplete`, so the
    /// Activity shows where you finished instead of going blank.
    static func current<E: ProgressExercise>(in exercises: [E]) -> Position? {
        let worked = exercises.filter { !$0.progressSets.isEmpty }
        guard let last = worked.last else { return nil }

        for exercise in worked {
            let sets = exercise.progressSets
            if let index = sets.firstIndex(where: { !$0.completed }) {
                return Position(
                    exerciseName: exercise.exerciseName,
                    setIndex: index + 1,
                    setCount: sets.count,
                    isComplete: false
                )
            }
        }

        return Position(
            exerciseName: last.exerciseName,
            setIndex: last.progressSets.count,
            setCount: last.progressSets.count,
            isComplete: true
        )
    }
}

extension Workout {
    /// Current position in this session, for the Live Activity.
    var progressPosition: WorkoutProgress.Position? {
        WorkoutProgress.current(in: orderedExercises)
    }
}
