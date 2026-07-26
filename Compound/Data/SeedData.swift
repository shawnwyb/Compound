import Foundation
import SwiftData

/// First-launch seeding of the default muscle groups and a starter exercise
/// library. Idempotent: does nothing if any `MuscleGroup` already exists.
enum SeedData {

    /// group name -> starter exercises filed under it
    ///
    /// Strength movements only. A set here is reps and load, with no duration or
    /// distance to record, so a treadmill run had nothing to log itself with —
    /// it drew the same "Lb / Reps" row as a bench press and was then skipped by
    /// every progression chart for having no weight. Cardio belongs here the day
    /// a set can describe one.
    static let starter: [(group: String, exercises: [String])] = [
        ("Chest",     ["Bench Press", "Incline Dumbbell Press", "Cable Fly", "Push-Up"]),
        ("Back",      ["Deadlift", "Pull-Up", "Bent-Over Row", "Lat Pulldown"]),
        ("Legs",      ["Back Squat", "Leg Press", "Romanian Deadlift", "Leg Curl"]),
        ("Shoulders", ["Overhead Press", "Lateral Raise", "Face Pull", "Rear Delt Fly"]),
        ("Arms",      ["Barbell Curl", "Triceps Pushdown", "Hammer Curl", "Skull Crusher"]),
        ("Abs",       ["Plank", "Hanging Leg Raise", "Cable Crunch", "Russian Twist"]),
    ]

    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<MuscleGroup>())) ?? 0
        guard existing == 0 else { return }

        for (index, entry) in starter.enumerated() {
            let group = MuscleGroup(name: entry.group, sortOrder: index)
            context.insert(group)
            for name in entry.exercises {
                context.insert(Exercise(name: name, group: group, isCustom: false))
            }
        }

        // Ensure the settings singleton exists up front.
        _ = Settings.current(in: context)

        do {
            try context.save()
        } catch {
            assertionFailure("Seeding failed: \(error)")
        }
    }
}
