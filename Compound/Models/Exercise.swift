import Foundation
import SwiftData

/// A single movement (e.g. "Bench Press") in the canonical library, independent
/// of any routine. Source of truth for muscle-group categorization on Stats.
@Model
final class Exercise {
    var id: UUID
    var name: String
    var isCustom: Bool
    var notes: String?

    /// Non-inverse side; inverse collection lives on `MuscleGroup.exercises`.
    var group: MuscleGroup?

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup? = nil,
        isCustom: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.group = group
        self.isCustom = isCustom
        self.notes = notes
    }
}

extension Exercise {

    /// Why a typed name can't be added to the library, or nil when it can.
    enum NameProblem: Equatable {
        case empty
        /// Carries the existing entry, so the message can name it rather than
        /// just refusing — "Bench Press is already in your library" tells the
        /// user where to look instead.
        case duplicate(String)
    }

    /// What a typed name is saved as: outer whitespace trimmed and inner runs
    /// collapsed to single spaces, so "  bench   press " and "bench press"
    /// can't both end up in the library looking identical.
    static func normalizedName(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Checks a typed name against the names already in the library. Matching is
    /// case-insensitive and diacritic-insensitive: the library is a list a human
    /// reads, and two entries differing only in capitalization are a mistake
    /// every time, not a distinction.
    static func nameProblem(_ raw: String, existing: [String]) -> NameProblem? {
        let name = normalizedName(raw)
        guard !name.isEmpty else { return .empty }
        let match = existing.first {
            normalizedName($0).compare(
                name,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
        return match.map { .duplicate($0) }
    }

    /// Removes a custom movement from the library. Starter entries are left
    /// alone — those are the ones that came with the app.
    ///
    /// Workout performances keep a snapshotted name and library id, so the log
    /// and stats still group them. Routine slots that pointed here are deleted
    /// (and the routine reindexed) so they don't linger as "Deleted exercise".
    func deleteFromLibrary(in context: ModelContext) {
        guard isCustom else { return }
        let libraryID = id
        // Fetch only sees what's in the store, and a custom exercise can be
        // created and deleted before autosave has flushed the routine slots
        // that already point at it.
        try? context.save()

        let performances = (try? context.fetch(FetchDescriptor<WorkoutExercise>())) ?? []
        for performed in performances where performed.exercise?.id == libraryID {
            performed.exerciseID = libraryID
            // Unidirectional — SwiftData will not nullify this for us.
            performed.exercise = nil
        }

        let planned = (try? context.fetch(FetchDescriptor<RoutineExercise>())) ?? []
        var routines: [Routine] = []
        var seen = Set<UUID>()
        for item in planned where item.exercise?.id == libraryID {
            if let routine = item.routine, seen.insert(routine.id).inserted {
                routines.append(routine)
            }
            // Linked through the parent the same way insert is: `context.delete`
            // updates the store but doesn't tell anything observing `routine.exercises`.
            item.routine?.exercises.removeAll { $0.id == item.id }
            context.delete(item)
        }

        group?.exercises.removeAll { $0.id == libraryID }
        context.delete(self)

        for routine in routines {
            for (index, item) in routine.orderedExercises.enumerated() {
                item.position = index
            }
        }
    }
}
