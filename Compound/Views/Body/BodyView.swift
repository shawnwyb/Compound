import SwiftUI
import SwiftData
import Charts

/// The Body tab: log a day's bodyweight and what you ate (freeform + calories),
/// see a bodyweight trend, and browse / edit any past day.
///
/// The screen always shows one *selected day*, edited inline at the top. The
/// common path is: open the app, paste your food, type the calorie estimate —
/// no navigation. Step between days with the chevrons, tap the date to jump to
/// any day, or tap a history row; when you're off today, a "Today" button snaps
/// you back.
struct BodyView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @Query private var settingsRows: [Settings]

    private let nav = DayNavigator()
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var current: DailyEntry?
    @State private var showDayPicker = false

    private var unit: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    private var today: Date { nav.startOfDay(.now) }
    private var isToday: Bool { nav.isToday(selectedDay, today: today) }

    /// Days with data other than the one on screen, newest first, by month.
    private var historySections: [MonthSection<DailyEntry>] {
        let others = entries.filter { $0.hasData && $0.date != selectedDay }
        return LogGrouping.sections(from: others, date: \.date)
    }

    /// Every day with a logged weight, oldest first — drives the trend chart.
    private var weightSeries: [DailyEntry] {
        entries.filter { $0.bodyWeight != nil }.sorted { $0.date < $1.date }
    }

    var body: some View {
        // Filtered and sorted once per render. As a computed property it ran
        // four times over — the count check, the chart, its Y domain, and the
        // latest reading each re-derived the whole series.
        let series = weightSeries

        NavigationStack {
            List {
                Section {
                    daySelector
                    if let current {
                        DailyEntryFields(entry: current, unit: unit)
                    }
                } header: {
                    Text("Entry").alignedSectionHeader()
                }

                if series.count >= 2 {
                    Section {
                        weightChart(series)
                            .frame(height: 180)
                            .padding(.vertical, 4)
                        if let latest = series.last?.bodyWeight {
                            LabeledContent("Latest", value: "\(formatWeight(latest)) \(unit)")
                                .font(.subheadline)
                        }
                    } header: {
                        Text("Weight").alignedSectionHeader()
                    }
                }

                ForEach(historySections, id: \.monthStart) { section in
                    Section {
                        ForEach(section.items) { entry in
                            Button {
                                selectedDay = entry.date
                            } label: {
                                HistoryRow(entry: entry, unit: unit)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { delete(at: $0, in: section.items) }
                    } header: {
                        Text(section.title)
                            .font(.subheadline)
                            .textCase(nil)
                            .alignedSectionHeader()
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(.compact)
            .navigationTitle("Body")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isToday {
                        Button("Today") { selectedDay = today }
                    }
                }
            }
            .onChange(of: selectedDay) { _, _ in
                loadDay()
                showDayPicker = false
            }
            .task { loadDay() }
            .onAppear(perform: cleanupEmpties)
        }
    }

    private var daySelector: some View {
        HStack {
            Button {
                selectedDay = nav.shifted(selectedDay, by: -1, today: today)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous day")

            Spacer()

            Button {
                showDayPicker = true
            } label: {
                VStack(spacing: 2) {
                    Text(isToday ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    HStack(spacing: 3) {
                        Text(selectedDay.formatted(.dateTime.month(.abbreviated).day().year()))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDayPicker) {
                DatePicker(
                    "Select day",
                    selection: dayPickerBinding,
                    in: ...today,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .presentationDetents([.medium])
            }

            Spacer()

            Button {
                selectedDay = nav.shifted(selectedDay, by: 1, today: today)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!nav.canGoForward(from: selectedDay, today: today))
            .accessibilityLabel("Next day")
        }
    }

    /// A padded Y range that never has zero span — a flat or single-point series
    /// would otherwise make Charts divide by zero and emit NaN to CoreGraphics.
    private func weightChartDomain(_ series: [DailyEntry]) -> ClosedRange<Double> {
        let weights = series.compactMap(\.bodyWeight)
        guard let lo = weights.min(), let hi = weights.max() else { return 0...1 }
        guard hi > lo else { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.1
        return (lo - pad)...(hi + pad)
    }

    private func weightChart(_ series: [DailyEntry]) -> some View {
        Chart(series) { entry in
            LineMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Weight", entry.bodyWeight ?? 0)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(.tint)

            PointMark(
                x: .value("Day", entry.date, unit: .day),
                y: .value("Weight", entry.bodyWeight ?? 0)
            )
            .foregroundStyle(.tint)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartYScale(domain: weightChartDomain(series))
        .accessibilityLabel("Bodyweight over time")
    }

    /// Normalizes the picked date to the start of its day.
    private var dayPickerBinding: Binding<Date> {
        Binding(
            get: { selectedDay },
            set: { selectedDay = nav.startOfDay($0) }
        )
    }

    private func loadDay() {
        current = DailyEntry.entry(on: selectedDay, in: context)
    }

    private func delete(at offsets: IndexSet, in items: [DailyEntry]) {
        for index in offsets {
            context.delete(items[index])
        }
    }

    /// Removes empty rows left behind from browsing other days (an entry is
    /// created whenever a day is opened, but only kept once something is
    /// logged). The day on screen and today are always left alone.
    private func cleanupEmpties() {
        for entry in entries where !entry.hasData && entry.date != today && entry.date != selectedDay {
            context.delete(entry)
        }
    }
}

/// The reusable weight / food / calories / protein rows, bound directly to a
/// `DailyEntry`. Numeric fields are backed by local text state so partial input
/// (e.g. a trailing decimal point) isn't clobbered mid-edit; the model is
/// updated on every change and SwiftData autosaves.
struct DailyEntryFields: View {
    @Bindable var entry: DailyEntry
    let unit: String

    @State private var weightText = ""
    @State private var caloriesText = ""
    @State private var proteinText = ""

    var body: some View {
        Group {
            LabeledContent("Weight") {
                HStack(spacing: 6) {
                    TextField("—", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                        .onChange(of: weightText) { _, new in
                            entry.bodyWeight = Double(new.replacingOccurrences(of: ",", with: "."))
                        }
                    Text(unit).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Food")
                foodEditor
            }
            .padding(.vertical, 2)

            LabeledContent("Calories") {
                HStack(spacing: 6) {
                    TextField("—", text: $caloriesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                        .onChange(of: caloriesText) { _, new in
                            entry.calories = Int(new.filter(\.isNumber))
                        }
                    Text("kcal").foregroundStyle(.secondary)
                }
            }

            LabeledContent("Protein") {
                HStack(spacing: 6) {
                    TextField("—", text: $proteinText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: 110)
                        .onChange(of: proteinText) { _, new in
                            entry.protein = Int(new.filter(\.isNumber))
                        }
                    Text("g").foregroundStyle(.secondary)
                }
            }
        }
        // Re-seed the text fields whenever we're pointed at a different day.
        .onChange(of: entry.id, initial: true) { _, _ in seed() }
    }

    private var foodEditor: some View {
        ZStack(alignment: .topLeading) {
            if entry.foodText.isEmpty {
                Text("What did you eat? Type or paste it here.")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $entry.foodText)
                .frame(minHeight: 130)
                .scrollContentBackground(.hidden)
        }
    }

    private func seed() {
        weightText = entry.bodyWeight.map(formatWeight) ?? ""
        caloriesText = entry.calories.map(String.init) ?? ""
        proteinText = entry.protein.map(String.init) ?? ""
    }
}

/// A history row: date, a metrics summary, and a one-line food snippet.
private struct HistoryRow: View {
    let entry: DailyEntry
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.headline)
                Spacer()
                if !metrics.isEmpty {
                    Text(metrics)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            if let snippet {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var metrics: String {
        var parts: [String] = []
        if let w = entry.bodyWeight { parts.append("\(formatWeight(w)) \(unit)") }
        if let c = entry.calories { parts.append("\(c) kcal") }
        if let p = entry.protein { parts.append("\(p)g") }
        return parts.joined(separator: " · ")
    }

    private var snippet: String? {
        let trimmed = entry.foodText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.replacingOccurrences(of: "\n", with: " ")
    }
}

/// Whole-number weights show without a decimal, otherwise one place.
private func formatWeight(_ weight: Double) -> String {
    weight == weight.rounded() ? String(Int(weight)) : String(format: "%.1f", weight)
}

#Preview {
    let _ = PreviewData.sampleBody
    BodyView()
        .modelContainer(PreviewData.container)
}
