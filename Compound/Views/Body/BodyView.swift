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
    /// Non-finite weights are excluded along with missing ones: plotting one
    /// hands Charts a NaN mark, and a single infinity blows the Y domain out to
    /// `-inf ... inf`, which makes every point NaN.
    private var weightSeries: [DailyEntry] {
        entries
            .filter { $0.bodyWeight?.isFinite == true }
            .sorted { $0.date < $1.date }
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
                            .frame(height: 184)
                            .padding(.vertical, 8)
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
                        Text(section.title).alignedSectionHeader()
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(16)
            // Weight, calories and protein use number pads, which have no return
            // key — swiping the list down is the only way back out of them.
            .scrollDismissesKeyboard(.interactively)
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Previous day")

            Spacer()

            Button {
                showDayPicker = true
            } label: {
                VStack(spacing: 4) {
                    Text(isToday ? "Today" : selectedDay.formatted(.dateTime.weekday(.wide)))
                        .font(.headline)
                    HStack(spacing: 4) {
                        Text(selectedDay.formatted(.dateTime.month(.abbreviated).day().year()))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Selected day, \(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))")
            .accessibilityHint("Jump to another day")
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
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(!nav.canGoForward(from: selectedDay, today: today))
            .accessibilityLabel("Next day")
        }
    }

    /// A padded Y range that never has zero span — a flat or single-point series
    /// would otherwise make Charts divide by zero and emit NaN to CoreGraphics.
    /// Non-finite weights are dropped first: `min()`/`max()` propagate a leading
    /// NaN, and `nan ... nan` is not a range a `ClosedRange` will form at all.
    private func weightChartDomain(_ series: [DailyEntry]) -> ClosedRange<Double> {
        let weights = series.compactMap(\.bodyWeight).filter(\.isFinite)
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
        let entry = DailyEntry.entry(on: selectedDay, in: context)
        // Clears a non-finite weight saved before the field rejected them, so
        // the day opens on an empty field rather than an unreadable one.
        if let weight = entry.bodyWeight, !weight.isFinite {
            entry.bodyWeight = nil
        }
        current = entry
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
    /// Drives the button's brief "Copied" state — a copy is otherwise completely
    /// silent, with nothing on screen to say it worked.
    @State private var copied = false
    @State private var copiedReset: Task<Void, Never>?
    @State private var showClearConfirm = false
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Numeric fields are sized for the values they hold, and grow with the
    /// text size rather than truncating them.
    @ScaledMetric(relativeTo: .body) private var numberFieldWidth: CGFloat = 110

    var body: some View {
        Group {
            LabeledContent("Weight") {
                HStack(spacing: 8) {
                    TextField("—", text:$weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: numberFieldWidth)
                        .onChange(of: weightText) { _, new in
                            entry.bodyWeight = WeightText.value(new)
                        }
                    Text(unit).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                foodHeader
                foodEditor
            }
            .padding(.vertical, 4)
            .sensoryFeedback(trigger: copied) { _, isCopied in
                isCopied ? .success : nil
            }

            LabeledContent("Calories") {
                HStack(spacing: 8) {
                    TextField("—", text:$caloriesText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: numberFieldWidth)
                        .onChange(of: caloriesText) { _, new in
                            entry.calories = Int(new.filter(\.isNumber))
                        }
                    Text("kcal").foregroundStyle(.secondary)
                }
            }

            LabeledContent("Protein") {
                HStack(spacing: 8) {
                    TextField("—", text:$proteinText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(maxWidth: numberFieldWidth)
                        .onChange(of: proteinText) { _, new in
                            entry.protein = Int(new.filter(\.isNumber))
                        }
                    Text("g").foregroundStyle(.secondary)
                }
            }

            // Last row in the section, well away from Paste — this is the one
            // control here that destroys work. Absent on a day with nothing on it.
            if entry.hasData {
                Button("Clear Day", role: .destructive) { showClearConfirm = true }
                    .confirmationDialog(
                        "Clear this day?",
                        isPresented: $showClearConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Clear Day", role: .destructive) { clearDay() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Removes the weight, food, calories, and protein logged for \(entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())). This can't be undone.")
                    }
            }
        }
        // Re-seed the text fields whenever we're pointed at a different day.
        .onChange(of: entry.id, initial: true) { _, _ in seed() }
    }

    /// The "Food" label with its Copy / Paste controls. The label keeps the same
    /// body size as Weight, Calories and Protein — only the buttons step down to
    /// subheadline — so the four rows still read as one column of labels.
    @ViewBuilder private var foodHeader: some View {
        // Label and buttons stop fitting on one line at accessibility sizes.
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 16))

        layout {
            Text("Food")
            if !stacked { Spacer(minLength: 16) }
            // 16 pt apart: enough that a thumb reaching for Paste can't catch
            // Copy, which would silently overwrite the pasteboard.
            HStack(spacing: 16) {
                if !entry.foodText.isEmpty { copyButton }
                pasteButton
            }
        }
    }

    private var copyButton: some View {
        Button { copyFood() } label: {
            ZStack {
                // Reserves the wider word so confirming the copy doesn't shove
                // Paste sideways under a thumb that's about to tap it.
                Text("Copied").hidden()
                Text(copied ? "Copied" : "Copy")
            }
            .font(.subheadline)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel("Copy food log")
    }

    /// The system paste control, not a `Button` reading `UIPasteboard`: the tap
    /// itself is the user's consent, so it skips the "Allow Paste?" alert that
    /// would otherwise appear on every single meal.
    ///
    /// It draws itself at a fixed 34 pt and ignores `controlSize` and
    /// `buttonStyle` alike (both measured), so it sits under the 44 pt target
    /// this app holds elsewhere. Left as the system draws it: that is the size
    /// Apple ships this control at, and the alternative — hand-rolling it —
    /// costs the permission-free paste, which is the whole point of using it.
    /// The 16 pt gap to Copy is what keeps it comfortable to hit.
    private var pasteButton: some View {
        PasteButton(payloadType: String.self) { appendPasted($0) }
            .labelStyle(.titleOnly)
            .buttonBorderShape(.capsule)
    }

    private var foodEditor: some View {
        ZStack(alignment: .topLeading) {
            if entry.foodText.isEmpty {
                // Names the expected content, like "Workout name" and "Routine
                // name" do — no worked example, nothing to date or contradict.
                Text("What you ate")
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

    /// Empties the day's four fields. The typed-text state is re-seeded by hand:
    /// it only reloads when the view is pointed at a *different* entry, so
    /// without this the cleared fields would keep showing their old numbers.
    private func clearDay() {
        entry.bodyWeight = nil
        entry.foodText = ""
        entry.calories = nil
        entry.protein = nil
        seed()
    }

    private func copyFood() {
        UIPasteboard.general.string = entry.foodText
        withAnimation(.snappy(duration: 0.2)) { copied = true }
        copiedReset?.cancel()
        copiedReset = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy(duration: 0.2)) { copied = false }
        }
    }

    private func appendPasted(_ strings: [String]) {
        entry.foodText = DailyEntry.appendingFood(
            strings.joined(separator: "\n"),
            to: entry.foodText
        )
    }
}

/// A history row: date, a metrics summary, and a one-line food snippet.
private struct HistoryRow: View {
    let entry: DailyEntry
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 4)
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

/// Whole-number weights show without a decimal, otherwise one place. A weight
/// that isn't a real number reads as no weight — `Int(_:)` traps on infinity,
/// which took the whole app down from a row that only wanted to draw a number.
private func formatWeight(_ weight: Double) -> String {
    guard weight.isFinite else { return "—" }
    return weight == weight.rounded() ? String(Int(weight)) : String(format: "%.1f", weight)
}

#Preview {
    let _ = PreviewData.sampleBody
    BodyView()
        .modelContainer(PreviewData.container)
}
