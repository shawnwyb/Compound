import Foundation

/// Pure day-stepping logic for the Body tab. Normalizes everything to the start
/// of a calendar day and never lets the selected day move into the future.
/// Kept free of SwiftData/SwiftUI so it can be unit-tested directly.
struct DayNavigator {
    var calendar: Calendar = .current

    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// `day` moved by `delta` calendar days, clamped so it never lands after
    /// `today`. Result is normalized to the start of the day.
    func shifted(_ day: Date, by delta: Int, today: Date) -> Date {
        let base = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: today)
        guard let moved = calendar.date(byAdding: .day, value: delta, to: base) else {
            return base
        }
        return min(moved, todayStart)
    }

    /// True when there is a later day to move to (the future is never allowed).
    func canGoForward(from day: Date, today: Date) -> Bool {
        calendar.startOfDay(for: day) < calendar.startOfDay(for: today)
    }

    func isToday(_ day: Date, today: Date) -> Bool {
        calendar.startOfDay(for: day) == calendar.startOfDay(for: today)
    }
}
