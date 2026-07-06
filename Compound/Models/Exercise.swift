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
