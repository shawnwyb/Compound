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
}
