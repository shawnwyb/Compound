import Foundation

/// One calendar-month bucket of dated items for the Log list.
struct MonthSection<Item> {
    let monthStart: Date
    /// Localized month + year, e.g. "July 2026".
    let title: String
    let items: [Item]

    var count: Int { items.count }
}

/// Pure month-bucketing for the Log tab. Operates on plain values so it can be
/// unit-tested without SwiftData/SwiftUI.
enum LogGrouping {

    /// Groups `items` into calendar months, newest month first. Within each
    /// month, items are sorted by `date` descending so same-day sessions stay
    /// as separate entries in chronological order.
    static func sections<Item>(
        from items: [Item],
        date: (Item) -> Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> [MonthSection<Item>] {
        var grouped: [Date: [Item]] = [:]
        for item in items {
            let start = monthStart(of: date(item), calendar: calendar)
            grouped[start, default: []].append(item)
        }

        var format = Date.FormatStyle()
            .month(.wide)
            .year()
            .locale(locale)
        format.calendar = calendar
        format.timeZone = calendar.timeZone

        return grouped.keys.sorted(by: >).map { start in
            let monthItems = grouped[start]!.sorted { date($0) > date($1) }
            return MonthSection(
                monthStart: start,
                title: start.formatted(format),
                items: monthItems
            )
        }
    }

    /// First instant of the calendar month containing `date`.
    static func monthStart(of date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}
