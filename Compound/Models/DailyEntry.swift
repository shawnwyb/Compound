import Foundation
import SwiftData

/// One calendar day of body data: a morning bodyweight plus a freeform,
/// copy-paste-friendly log of what was eaten and its estimated calories.
///
/// The design is deliberately dumb: the app is just the ledger. Calorie
/// estimation happens outside the app (e.g. pasted from an LLM), so this stores
/// only a text blob and a couple of numbers — no food database, nothing that
/// breaks the offline-first / no-backend model.
///
/// At most one entry exists per calendar day; fetch-or-create via
/// `DailyEntry.entry(on:in:)`. `date` is normalized to the start of the day so
/// it can act as that day's key.
@Model
final class DailyEntry {
    var id: UUID
    /// Start of the calendar day this entry belongs to (its unique key).
    var date: Date
    /// Bodyweight in the user's currently chosen unit; nil if not logged.
    /// Converted alongside `SetEntry.weight` when the unit system changes.
    var bodyWeight: Double?
    /// Freeform description of what was eaten — built to be pasted into.
    var foodText: String
    /// Estimated calories for the day (typically pasted from an LLM estimate).
    var calories: Int?
    /// Protein in grams — the one macro worth eyeballing for lifters. Optional.
    var protein: Int?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        bodyWeight: Double? = nil,
        foodText: String = "",
        calories: Int? = nil,
        protein: Int? = nil,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.bodyWeight = bodyWeight
        self.foodText = foodText
        self.calories = calories
        self.protein = protein
    }
}

extension DailyEntry {
    /// True once the user has entered anything worth keeping. Empty rows are
    /// hidden from history and skipped in exports, and cleaned up on appear.
    var hasData: Bool {
        bodyWeight != nil
            || calories != nil
            || protein != nil
            || !foodText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Text pasted into the food log, joined onto what's already there: on its
    /// own line, and on exactly one — trailing blank space in `existing` is
    /// dropped first, so a box already ending in a newline doesn't gain a gap.
    /// Appends rather than replaces: a day's food arrives in several goes, and
    /// there is no undo for a paste that wiped the morning.
    static func appendingFood(_ pasted: String, to existing: String) -> String {
        let addition = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !addition.isEmpty else { return existing }
        var kept = existing
        while let last = kept.last, last.isWhitespace { kept.removeLast() }
        return kept.isEmpty ? addition : kept + "\n" + addition
    }

    /// The half-open `[start, end)` instant range of the calendar day
    /// containing `date`. Pure and testable — the fetch-or-create below and its
    /// day-boundary behavior are defined entirely by this.
    static func dayBounds(
        for date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    /// The singleton entry for the calendar day containing `date`, creating and
    /// inserting it if absent (mirrors `Settings.current(in:)`).
    static func entry(
        on date: Date,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> DailyEntry {
        let (dayStart, dayEnd) = dayBounds(for: date, calendar: calendar)
        var descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = DailyEntry(date: dayStart, calendar: calendar)
        context.insert(created)
        return created
    }
}
