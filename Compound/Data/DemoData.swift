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

    /// One progressive plan per exercise: a starting weight in pounds, a working
    /// rep target, and how the load creeps up — `step` pounds added once every
    /// `every` times the exercise is performed.
    ///
    /// Steps are sizes you can actually load: 5 lb on a barbell (2.5 a side),
    /// 5 lb a hand on dumbbells, 10 lb on a cable stack, 45 on the leg press.
    /// `every` then sets the pace, because real accessory work doesn't move
    /// every session. Between them they keep each lift's gain over the block
    /// near what the movement can really add — big compounds climbing faster in
    /// percentage terms than the isolation work hanging off them.
    private typealias PlanItem = (name: String, base: Double, step: Double, reps: Int, every: Int)

    /// A push / pull / legs split, run on rotation. Every day keeps the same
    /// movements so each lift's progression reads as one line rather than a
    /// scatter, and the names all come from `SeedData.starter` — an exercise the
    /// library doesn't have is silently skipped when seeding.
    ///
    /// Bodyweight movements are left out on purpose: `StatsCalculator` only
    /// tracks sets with a weight, so a seeded Pull-Up would log fine and then
    /// never appear in the progression picker.
    private static let split: [(day: String, exercises: [PlanItem])] = [
        ("Push", [
            ("Bench Press",             135,  5, 5,  2),
            ("Overhead Press",           75,  2.5, 6,  2),
            ("Incline Dumbbell Press",   45,  5, 8,  4),
            ("Lateral Raise",            15,  5, 15, 4),
            ("Triceps Pushdown",         50, 10, 12, 4),
        ]),
        ("Pull", [
            ("Deadlift",                225, 10, 3,  2),
            ("Bent-Over Row",           115,  5, 8,  2),
            ("Lat Pulldown",            100, 10, 10, 4),
            ("Barbell Curl",             60,  5, 10, 4),
            ("Face Pull",                40, 10, 15, 4),
        ]),
        ("Legs", [
            ("Back Squat",              185, 10, 5,  2),
            ("Romanian Deadlift",       135, 10, 8,  3),
            ("Leg Press",               270, 45, 10, 4),
            ("Leg Curl",                 70, 10, 12, 4),
        ]),
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

        // 24 sessions over the last ~7 weeks: push / pull / legs every other
        // day, eight rounds of each. The most recent lands yesterday so the
        // streak and "last 7 days" tiles have something in them.
        let sessionCount = 24
        for session in 0..<sessionCount {
            let daysAgo = (sessionCount - 1 - session) * 2 + 1
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let day = split[session % split.count]

            let workout = Workout(
                routineName: day.day,
                date: date,
                startedAt: date,
                durationSeconds: 3000 + (session % 4) * 300,
                finishedAt: date
            )
            context.insert(workout)

            for (position, item) in day.exercises.enumerated() {
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
                // One loadable jump every `every` appearances. The sessions in
                // between repeat the weight, which is what a block actually
                // looks like — nobody adds to a lateral raise every week.
                let weight = item.base + item.step * Double(n / item.every)

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

    /// One routine per day of the split, built from the same table the history
    /// is — so starting "Push" prefills exactly the movements the seeded push
    /// sessions contain, and the two can't drift apart.
    private static func seedRoutines(_ context: ModelContext, exercise: (String) -> Exercise?) {
        guard ((try? context.fetchCount(FetchDescriptor<Routine>())) ?? 0) == 0 else { return }
        for (order, day) in split.enumerated() {
            let routine = Routine(name: day.day, sortOrder: order)
            context.insert(routine)
            for (position, item) in day.exercises.enumerated() {
                guard let source = exercise(item.name) else { continue }
                let routineExercise = RoutineExercise(exercise: source, targetSets: 3, position: position)
                context.insert(routineExercise)
                routineExercise.routine = routine
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
