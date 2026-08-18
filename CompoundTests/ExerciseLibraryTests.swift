import XCTest
import SwiftData
@testable import Compound

/// Side effects of removing a custom movement from the library. The picker UI
/// is verified by using the app; this covers the store so a delete can't leave
/// nameless routine slots or split a lift's stats history.
@MainActor
final class ExerciseLibraryTests: XCTestCase {

    private func makeStore() throws -> ModelContainer {
        try ModelContainer(
            for: AppSchema.model,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testStarterExercisesAreLeftAlone() throws {
        let store = try makeStore()
        let context = store.mainContext
        let group = MuscleGroup(name: "Chest", sortOrder: 0)
        context.insert(group)
        let bench = Exercise(name: "Bench Press", group: group, isCustom: false)
        context.insert(bench)
        group.exercises.append(bench)

        bench.deleteFromLibrary(in: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(remaining.map(\.id), [bench.id])
    }

    func testCustomExerciseIsRemovedFromTheLibrary() throws {
        let store = try makeStore()
        let context = store.mainContext
        let group = MuscleGroup(name: "Legs", sortOrder: 0)
        context.insert(group)
        let custom = Exercise(name: "Hip Thrust", group: group, isCustom: true)
        context.insert(custom)
        group.exercises.append(custom)
        let customID = custom.id

        custom.deleteFromLibrary(in: context)

        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        XCTAssertFalse(remaining.contains { $0.id == customID })
        XCTAssertFalse(group.exercises.contains { $0.id == customID })
    }

    func testDeletingRemovesRoutineSlotsAndReindexes() throws {
        let store = try makeStore()
        let context = store.mainContext
        let group = MuscleGroup(name: "Chest", sortOrder: 0)
        context.insert(group)
        let custom = Exercise(name: "Floor Press", group: group, isCustom: true)
        let bench = Exercise(name: "Bench Press", group: group, isCustom: false)
        let fly = Exercise(name: "Cable Fly", group: group, isCustom: false)
        context.insert(custom)
        context.insert(bench)
        context.insert(fly)

        let routine = Routine(name: "Push", sortOrder: 0)
        context.insert(routine)
        for (index, exercise) in [custom, bench, fly].enumerated() {
            let item = RoutineExercise(exercise: exercise, targetSets: 3, position: index)
            context.insert(item)
            routine.exercises.append(item)
        }

        custom.deleteFromLibrary(in: context)

        XCTAssertEqual(routine.orderedExercises.map { $0.exercise?.name }, ["Bench Press", "Cable Fly"])
        XCTAssertEqual(routine.orderedExercises.map(\.position), [0, 1])
    }

    /// Pre-migration performances may have a nil snapshot. Delete fills it in
    /// before the relationship is nullified, so stats still group by the
    /// library id rather than each workout row's own id.
    func testWorkoutHistoryKeepsNameAndIdentityAfterDelete() throws {
        let store = try makeStore()
        let context = store.mainContext
        let group = MuscleGroup(name: "Legs", sortOrder: 0)
        context.insert(group)
        let custom = Exercise(name: "Hip Thrust", group: group, isCustom: true)
        context.insert(custom)
        let customID = custom.id

        let workout = Workout(routineName: "Lower", date: .now, startedAt: .now, finishedAt: .now)
        context.insert(workout)
        let performed = WorkoutExercise(
            exercise: custom,
            exerciseName: custom.name,
            position: 0
        )
        performed.exerciseID = nil
        context.insert(performed)
        workout.exercises.append(performed)
        let set = SetEntry(setNumber: 1, reps: 8, weight: 185, completed: true)
        context.insert(set)
        performed.sets.append(set)

        custom.deleteFromLibrary(in: context)

        XCTAssertNil(performed.exercise)
        XCTAssertEqual(performed.exerciseName, "Hip Thrust")
        XCTAssertEqual(performed.exerciseID, customID)
        XCTAssertEqual(performed.resolvedExerciseID, customID)

        let snapshot = StatsSnapshot.from([workout])
        XCTAssertEqual(snapshot.first?.exercises.first?.exerciseID, customID)
        XCTAssertEqual(snapshot.first?.exercises.first?.exerciseName, "Hip Thrust")
        let tracked = StatsCalculator.trackedExercises(in: snapshot)
        XCTAssertEqual(tracked.map(\.id), [customID])
    }
}
