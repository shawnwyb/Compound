import Foundation
import SwiftData

/// Single source of truth for the SwiftData schema, shared by the live app,
/// previews, and (later) tests.
enum AppSchema {
    static let model = Schema([
        MuscleGroup.self,
        Exercise.self,
        Routine.self,
        RoutineExercise.self,
        Workout.self,
        WorkoutExercise.self,
        SetEntry.self,
        Settings.self,
        DailyEntry.self,
    ])
}
