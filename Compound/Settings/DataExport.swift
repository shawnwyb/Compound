import Foundation
import SwiftData

/// JSON export of the local store for backup / share.
enum DataExport {

    nonisolated struct Payload: Codable, Sendable {
        var exportedAt: Date
        var settings: SettingsDTO
        var muscleGroups: [MuscleGroupDTO]
        var exercises: [ExerciseDTO]
        var routines: [RoutineDTO]
        var workouts: [WorkoutDTO]
        var dailyEntries: [DailyEntryDTO]
    }

    nonisolated struct SettingsDTO: Codable, Sendable {
        var units: String
        var defaultRestSeconds: Int
        var restSoundEnabled: Bool
        var restVibrationEnabled: Bool
        var theme: String
        var restPresets: [Int]
    }

    nonisolated struct MuscleGroupDTO: Codable, Sendable {
        var id: UUID
        var name: String
        var sortOrder: Int
    }

    nonisolated struct ExerciseDTO: Codable, Sendable {
        var id: UUID
        var name: String
        var groupID: UUID?
        var isCustom: Bool
        var notes: String?
    }

    nonisolated struct RoutineDTO: Codable, Sendable {
        var id: UUID
        var name: String
        var createdAt: Date
        var sortOrder: Int
        var exercises: [RoutineExerciseDTO]
    }

    nonisolated struct RoutineExerciseDTO: Codable, Sendable {
        var id: UUID
        var exerciseID: UUID?
        var targetSets: Int
        var position: Int
    }

    nonisolated struct WorkoutDTO: Codable, Sendable {
        var id: UUID
        var routineID: UUID?
        var routineName: String
        var date: Date
        var startedAt: Date
        var durationSeconds: Int
        var editedAt: Date?
        var exercises: [WorkoutExerciseDTO]
    }

    nonisolated struct WorkoutExerciseDTO: Codable, Sendable {
        var id: UUID
        var exerciseID: UUID?
        var exerciseName: String
        var position: Int
        var sets: [SetDTO]
    }

    nonisolated struct SetDTO: Codable, Sendable {
        var id: UUID
        var setNumber: Int
        var reps: Int
        var weight: Double
        var completed: Bool
        var restSeconds: Int?
    }

    nonisolated struct DailyEntryDTO: Codable, Sendable {
        var id: UUID
        var date: Date
        var bodyWeight: Double?
        var foodText: String
        var calories: Int?
        var protein: Int?
    }

    /// Builds a Codable payload from the live store.
    @MainActor
    static func payload(from context: ModelContext) throws -> Payload {
        let settings = Settings.current(in: context)
        let groups = try context.fetch(FetchDescriptor<MuscleGroup>(sortBy: [SortDescriptor(\.sortOrder)]))
        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        let routines = try context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.sortOrder)]))
        // Exclude in-progress workouts (`isInProgress`) from the backup.
        let workouts = try context.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.finishedAt != nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))
        let dailyEntries = try context.fetch(FetchDescriptor<DailyEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]))

        return Payload(
            exportedAt: .now,
            settings: SettingsDTO(
                units: settings.units.rawValue,
                defaultRestSeconds: settings.defaultRestSeconds,
                restSoundEnabled: settings.restSoundEnabled,
                restVibrationEnabled: settings.restVibrationEnabled,
                theme: settings.theme.rawValue,
                restPresets: settings.restPresets
            ),
            muscleGroups: groups.map {
                MuscleGroupDTO(id: $0.id, name: $0.name, sortOrder: $0.sortOrder)
            },
            exercises: exercises.map {
                ExerciseDTO(
                    id: $0.id,
                    name: $0.name,
                    groupID: $0.group?.id,
                    isCustom: $0.isCustom,
                    notes: $0.notes
                )
            },
            routines: routines.map { routine in
                RoutineDTO(
                    id: routine.id,
                    name: routine.name,
                    createdAt: routine.createdAt,
                    sortOrder: routine.sortOrder,
                    exercises: routine.orderedExercises.map { item in
                        RoutineExerciseDTO(
                            id: item.id,
                            exerciseID: item.exercise?.id,
                            targetSets: item.targetSets,
                            position: item.position
                        )
                    }
                )
            },
            workouts: workouts.map { workout in
                WorkoutDTO(
                    id: workout.id,
                    routineID: workout.routineID,
                    routineName: workout.routineName,
                    date: workout.date,
                    startedAt: workout.startedAt,
                    durationSeconds: workout.durationSeconds,
                    editedAt: workout.editedAt,
                    exercises: workout.orderedExercises.map { performed in
                        WorkoutExerciseDTO(
                            id: performed.id,
                            exerciseID: performed.exercise?.id,
                            exerciseName: performed.exerciseName,
                            position: performed.position,
                            sets: performed.orderedSets.map { set in
                                SetDTO(
                                    id: set.id,
                                    setNumber: set.setNumber,
                                    reps: set.reps,
                                    weight: set.weight,
                                    completed: set.completed,
                                    restSeconds: set.restSeconds
                                )
                            }
                        )
                    }
                )
            },
            dailyEntries: dailyEntries.filter(\.hasData).map { entry in
                DailyEntryDTO(
                    id: entry.id,
                    date: entry.date,
                    bodyWeight: entry.bodyWeight,
                    foodText: entry.foodText,
                    calories: entry.calories,
                    protein: entry.protein
                )
            }
        )
    }

    /// UTF-8 JSON data, pretty-printed for readability.
    ///
    /// Encoding runs off the main actor. Reading the store has to happen on it —
    /// SwiftData models aren't `Sendable` and belong to the main context — but
    /// serializing the resulting value tree is pure work that would otherwise
    /// freeze the UI for the length of a whole history.
    @MainActor
    static func jsonData(from context: ModelContext) async throws -> Data {
        let payload = try payload(from: context)
        return try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(payload)
        }.value
    }

    /// Suggested filename for a share/export, e.g. `compound-backup-2026-07-12.json`.
    static func suggestedFileName(now: Date = .now) -> String {
        let stamp = now.formatted(
            Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()
        )
        return "compound-backup-\(stamp).json"
    }
}
