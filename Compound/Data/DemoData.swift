#if DEBUG
import Foundation
import SwiftData

/// Debug-only demo data for exercising the app on a real simulator without
/// SwiftUI previews. Driven by launch arguments so it can be scripted:
///
///   xcrun simctl launch booted Oriented.Compound -seedDemoData YES
///   xcrun simctl launch booted Oriented.Compound -wipeData YES
///
/// `seed` is idempotent (skips if any workout already exists) so re-launching
/// with the flag won't pile up duplicates. `wipe` clears every model — the base
/// exercise library reseeds on the next normal launch. Compiled only in DEBUG,
/// so none of this ships in a Release build.
enum DemoData {

    /// Reads launch arguments and applies any requested action. Called once at
    /// startup, after the base library has been seeded.
    static func handleLaunchArguments(context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-wipeData") {
            wipe(context)
        }
        if args.contains("-seedDemoData") {
            seed(context)
        }
    }

    // MARK: - Seeding

    /// One progressive plan per exercise: a base weight, a per-session step, and
    /// a working rep target.
    private static let plan: [(name: String, base: Double, step: Double, reps: Int)] = [
        ("Bench Press",    135, 2.5, 5),
        ("Back Squat",     185, 5.0, 5),
        ("Deadlift",       225, 5.0, 3),
        ("Overhead Press",  75, 1.5, 6),
        ("Bent-Over Row",  115, 2.5, 8),
    ]

    static func seed(_ context: ModelContext) {
        // Make sure the starter library exists to attach workouts to.
        if ((try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0) == 0 {
            SeedData.seedIfNeeded(context: context)
        }
        // Idempotent: only seed demo history once.
        guard ((try? context.fetchCount(FetchDescriptor<Workout>())) ?? 0) == 0 else { return }

        let library = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        func exercise(_ name: String) -> Exercise? { library.first { $0.name == name } }

        let calendar = Calendar.current
        var appearances: [String: Int] = [:]

        // ~24 sessions over the last ~8 weeks, three exercises each, rotating.
        let sessionCount = 24
        for session in 0..<sessionCount {
            let daysAgo = (sessionCount - session) * 3
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now

            let workout = Workout(
                routineName: session % 2 == 0 ? "Full Body A" : "Full Body B",
                date: date,
                startedAt: date,
                durationSeconds: 3000 + (session % 4) * 300
            )
            context.insert(workout)

            let picks = (0..<3).map { plan[(session + $0) % plan.count] }
            for (position, item) in picks.enumerated() {
                guard let source = exercise(item.name) else { continue }
                let performed = WorkoutExercise(
                    exercise: source,
                    exerciseName: source.name,
                    position: position
                )
                context.insert(performed)
                performed.workout = workout

                let n = appearances[item.name, default: 0]
                appearances[item.name] = n + 1
                // Steady climb with a mild deload every third appearance.
                let weight = item.base + item.step * Double(n) - (n % 3 == 2 ? item.step : 0)

                for setNumber in 1...3 {
                    let entry = SetEntry(
                        setNumber: setNumber,
                        reps: item.reps,
                        weight: weight,
                        completed: setNumber < 3 || session % 5 != 0 // occasional missed last set
                    )
                    context.insert(entry)
                    entry.workoutExercise = performed
                }
            }
        }

        seedRoutines(context, exercise: exercise)
        seedBody(context, calendar: calendar)

        try? context.save()
    }

    private static func seedRoutines(_ context: ModelContext, exercise: (String) -> Exercise?) {
        guard ((try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0) == 0 else { return }
        let templates: [(name: String, exercises: [String])] = [
            ("Full Body A", ["Bench Press", "Back Squat", "Bent-Over Row"]),
            ("Full Body B", ["Deadlift", "Overhead Press", "Barbell Curl"]),
        ]
        for (order, template) in templates.enumerated() {
            let routine = Routine(name: template.name, sortOrder: order)
            context.insert(routine)
            for (position, name) in template.exercises.enumerated() {
                guard let source = exercise(name) else { continue }
                let item = RoutineExercise(exercise: source, targetSets: 3, position: position)
                context.insert(item)
                item.routine = routine
            }
        }
    }

    private static func seedBody(_ context: ModelContext, calendar: Calendar) {
        // 30 days of a gentle cut: bodyweight drifting down, calories/protein logged.
        for daysAgo in stride(from: 30, through: 1, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) else { continue }
            let progress = Double(30 - daysAgo)
            let wiggle = (daysAgo % 2 == 0) ? 0.4 : -0.3
            let entry = DailyEntry(
                date: date,
                bodyWeight: 185.0 - progress * 0.18 + wiggle,
                foodText: daysAgo % 4 == 0 ? "Oats + eggs, chicken & rice, salmon & veg, greek yogurt" : "",
                calories: 2000 + (daysAgo % 5) * 60,
                protein: 160 + (daysAgo % 3) * 5
            )
            context.insert(entry)
        }
    }

    // MARK: - Wiping

    static func wipe(_ context: ModelContext) {
        // Delete per object (not `delete(model:)`): batch deletes bypass the
        // object graph and trip mandatory inverse-nullify constraints on
        // RoutineExercise.routine / Exercise.group. Children first so parent
        // cascades have nothing left to touch.
        deleteAll(SetEntry.self, in: context)
        deleteAll(WorkoutExercise.self, in: context)
        deleteAll(Workout.self, in: context)
        deleteAll(RoutineExercise.self, in: context)
        deleteAll(Routine.self, in: context)
        deleteAll(DailyEntry.self, in: context)
        deleteAll(Exercise.self, in: context)
        deleteAll(MuscleGroup.self, in: context)
        deleteAll(Settings.self, in: context)
        try? context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        let items = (try? context.fetch(FetchDescriptor<T>())) ?? []
        for item in items {
            context.delete(item)
        }
    }
}
#endif
