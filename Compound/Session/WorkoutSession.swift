import Foundation
import Observation

/// One editable set inside a live session (reference type for direct SwiftUI binding).
@Observable
final class SessionSet: Identifiable {
    let id = UUID()
    var setNumber: Int
    /// The value the user has actually typed. `0` means "not entered yet" — the
    /// row shows `targetReps`/`targetWeight` as a grey placeholder instead.
    var reps: Int
    var weight: Double
    /// The planned/previous values, shown as ghost placeholders and used as the
    /// logged value when the user leaves a set untouched.
    var targetReps: Int
    var targetWeight: Double
    var note: String
    var completed: Bool

    init(
        setNumber: Int,
        reps: Int = 0,
        weight: Double = 0,
        targetReps: Int = 0,
        targetWeight: Double = 0,
        note: String = "",
        completed: Bool = false
    ) {
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.note = note
        self.completed = completed
    }

    /// What actually gets logged: the typed value, or the target if untouched.
    var effectiveReps: Int { reps != 0 ? reps : targetReps }
    var effectiveWeight: Double { weight != 0 ? weight : targetWeight }
}

/// One exercise inside a live session, holding its ordered sets.
@Observable
final class SessionExercise: Identifiable {
    let id = UUID()
    /// Reference kept only to link `WorkoutExercise.exercise` on save.
    let exercise: Exercise?
    let name: String
    var sets: [SessionSet]

    init(exercise: Exercise?, name: String, sets: [SessionSet]) {
        self.exercise = exercise
        self.name = name
        self.sets = sets
    }

    /// Appends a new set, carrying the previous set's weight forward as the
    /// target (ghost) so the new row starts empty with that value hinted.
    func addSet() {
        sets.append(
            SessionSet(
                setNumber: sets.count + 1,
                targetReps: sets.last?.effectiveReps ?? 0,
                targetWeight: sets.last?.effectiveWeight ?? 0
            )
        )
    }

    /// Removes sets at the given offsets and re-sequences the set numbers.
    func deleteSets(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where sets.indices.contains(index) {
            sets.remove(at: index)
        }
        for (index, set) in sets.enumerated() {
            set.setNumber = index + 1
        }
    }
}

/// The between-set rest timer. Transient UI state — only the elapsed value is
/// ever persisted (to `SetEntry.restSeconds`), never the timer itself.
@Observable
final class RestTimer {
    private(set) var endDate: Date?
    private(set) var duration: Int = 0

    var isActive: Bool { endDate != nil }

    func start(seconds: Int) {
        guard seconds > 0 else { return }
        duration = seconds
        endDate = Date.now.addingTimeInterval(TimeInterval(seconds))
    }

    func stop() {
        endDate = nil
    }

    /// Add or remove time, never pushing the end before the current moment.
    func adjust(by seconds: Int) {
        guard let end = endDate else { return }
        endDate = max(end.addingTimeInterval(TimeInterval(seconds)), Date.now)
    }

    func remaining(at now: Date = .now) -> Int {
        guard let end = endDate else { return 0 }
        return RestCountdown.remaining(endDate: end, now: now)
    }
}

/// The heart of the app: an in-progress workout held in memory and only
/// materialized into SwiftData when the user finishes.
@Observable
final class WorkoutSession: Identifiable {
    let id = UUID()
    let routineID: UUID?
    let routineName: String
    let startedAt: Date
    var exercises: [SessionExercise]
    let rest = RestTimer()

    init(
        routineID: UUID?,
        routineName: String,
        startedAt: Date = .now,
        exercises: [SessionExercise]
    ) {
        self.routineID = routineID
        self.routineName = routineName
        self.startedAt = startedAt
        self.exercises = exercises
    }

    /// Elapsed session time — the source of `Workout.durationSeconds` on finish.
    func elapsedSeconds(at now: Date = .now) -> Int {
        max(0, Int(now.timeIntervalSince(startedAt)))
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.completed).count }
    }

    /// Toggles a set's completion. The rest timer is started manually by the
    /// user, never automatically here.
    func toggle(_ set: SessionSet) {
        set.completed.toggle()
    }
}
