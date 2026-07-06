import Foundation
import SwiftData

/// A category exercises are filed under (Abs, Back, Chest, …).
/// Seeded with a default set on first launch; users can add custom groups.
@Model
final class MuscleGroup {
    var id: UUID
    var name: String
    var sortOrder: Int

    /// Deleting a group leaves its exercises intact with `group == nil`
    /// (surfaced as "Uncategorized" in the UI) rather than destroying history.
    @Relationship(deleteRule: .nullify, inverse: \Exercise.group)
    var exercises: [Exercise] = []

    init(id: UUID = UUID(), name: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}
