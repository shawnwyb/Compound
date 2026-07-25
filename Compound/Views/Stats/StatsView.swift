import SwiftUI
import SwiftData
import Charts

/// Progress tab: a consistency snapshot plus two progression explorers — one for
/// lifts (an exercise's top set / est. 1RM / volume over time) and one for body
/// metrics (bodyweight / calories / protein). Each explorer shares the same
/// picker → range → line chart → summary layout.
struct StatsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \DailyEntry.date) private var dailyEntries: [DailyEntry]
    @Query private var settingsRows: [Settings]

    // Lifts explorer state.
    @State private var exerciseSelection: UUID?
    @State private var exerciseMetric: ExerciseMetric = .topSetWeight
    @State private var liftsRange: StatsRange = .month3

    // Body explorer state.
    @State private var bodyMetricSelection: BodyMetric?
    @State private var bodyRange: StatsRange = .month3

    /// Everything on this screen, derived once per data change rather than once
    /// per render — see `StatsDigest` for why building it in `body` is a trap.
    /// nil until the first build, which is a blank frame rather than a flash of
    /// the empty state.
    @State private var digest: StatsDigest?

    private let calendar = Calendar.current

    /// What a chart/summary is currently plotting, so formatting can adapt.
    private enum SeriesKind {
        case exercise(ExerciseMetric)
        case body(BodyMetric)
    }

    // MARK: - Derived data

    private var unitLabel: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    // MARK: - Body

    /// A cheap fingerprint of the store, used to notice data changes without
    /// reading any of it: counts, plus the newest workout's identity and finish
    /// state (which is what changes when a session is finished). Deliberately
    /// never touches exercises or sets — reading those here is exactly the
    /// dependency this screen is trying not to have. Anything it misses, such
    /// as an edit to an old workout, is caught by the rebuild on appear.
    private var dataRevision: Int {
        var hasher = Hasher()
        hasher.combine(workouts.count)
        hasher.combine(workouts.first?.id)
        hasher.combine(workouts.first?.finishedAt)
        hasher.combine(dailyEntries.count)
        return hasher.finalize()
    }

    private func rebuildDigest() {
        digest = StatsDigest(workouts: workouts, entries: dailyEntries)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let digest {
                    content(digest)
                } else {
                    Color.clear
                }
            }
            .navigationTitle("Stats")
        }
        // Outside `body` on purpose: the digest walks every set, and a read of
        // a model property during a body evaluation subscribes this view to
        // that object for the life of the screen.
        .onAppear(perform: rebuildDigest)
        .onChange(of: dataRevision) { _, _ in rebuildDigest() }
        // Every number here is measured from "today", and the digest froze that
        // when it was built. Left open on this tab overnight, nothing else
        // would notice: `onAppear` doesn't fire again on foreground and no data
        // changed. Guarded on the day actually turning so unlocking your phone
        // doesn't pay for a rebuild it doesn't need.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let digest,
                  !calendar.isDate(digest.builtAt, inSameDayAs: .now)
            else { return }
            rebuildDigest()
        }
    }

    @ViewBuilder
    private func content(_ digest: StatsDigest) -> some View {
        if !digest.hasAnyData {
            ContentUnavailableView {
                Label("No Stats Yet", systemImage: "chart.xyaxis.line")
            } description: {
                // One finished workout is enough to clear this, and any Body
                // figure counts — calories and protein, not just weight. Keep
                // this in step with `StatsDigest.hasAnyData`.
                Text("Progress appears once you've finished a workout or logged something on the Body tab.")
            }
        } else {
            List {
                if digest.hasFinishedWorkouts {
                    Section {
                        overviewGrid(digest)
                    } header: {
                        Text("Overview").alignedSectionHeader()
                    }
                }
                if digest.hasAnyExercise {
                    Section {
                        liftsSection(digest)
                    } header: {
                        Text("Lifts").alignedSectionHeader()
                    }
                }
                if digest.hasAnyBody {
                    Section {
                        bodySection(digest)
                    } header: {
                        Text("Body").alignedSectionHeader()
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(16)
        }
    }

    // MARK: - Overview

    private func overviewGrid(_ digest: StatsDigest) -> some View {
        HStack(spacing: 8) {
            statTile(title: "Workouts", value: "\(digest.workoutCount)")
            statTile(title: "Streak", value: "\(digest.streak.current)d")
            statTile(title: "Last 7d", value: "\(digest.streak.daysLast7)")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
        // Read as one "Workouts, 12" element rather than two stray fragments.
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lifts explorer

    @ViewBuilder
    private func liftsSection(_ digest: StatsDigest) -> some View {
        // Resolved and plotted once, then handed to both the chart and the
        // summary — each read used to rebuild the series from scratch.
        let selectedID = digest.resolvedExerciseID(selection: exerciseSelection)
        let points = digest.liftsPoints(exerciseID: selectedID, metric: exerciseMetric, range: liftsRange)

        Picker("Exercise", selection: Binding(get: { selectedID }, set: { exerciseSelection = $0 })) {
            ForEach(digest.tracked) { exercise in
                Text(exercise.name).tag(Optional(exercise.id))
            }
        }
        .pickerStyle(.navigationLink)

        Picker("Measure", selection: $exerciseMetric) {
            ForEach(ExerciseMetric.allCases) { metric in
                Text(metric.label).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)

        rangePicker($liftsRange)

        let kind = SeriesKind.exercise(exerciseMetric)
        chartView(points: points, kind: kind, range: liftsRange)
        summaryRows(points: points, kind: kind, range: liftsRange)
    }

    // MARK: - Body explorer

    @ViewBuilder
    private func bodySection(_ digest: StatsDigest) -> some View {
        let metric = digest.resolvedBodyMetric(selection: bodyMetricSelection)
        let points = digest.bodyPoints(metric: metric, range: bodyRange)

        Picker("Metric", selection: Binding(get: { metric }, set: { bodyMetricSelection = $0 })) {
            ForEach(BodyMetric.allCases) { metric in
                Text(metric.label).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)

        rangePicker($bodyRange)

        let kind = SeriesKind.body(metric)
        chartView(points: points, kind: kind, range: bodyRange)
        summaryRows(points: points, kind: kind, range: bodyRange)
    }

    private func rangePicker(_ selection: Binding<StatsRange>) -> some View {
        Picker("Range", selection: selection) {
            ForEach(StatsRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
    }

    // MARK: - Chart

    @ViewBuilder
    private func chartView(points series: [SeriesPoint], kind: SeriesKind, range: StatsRange) -> some View {
        // A value that isn't a real number has no position on the plot: Charts
        // passes it to CoreGraphics as NaN, and one infinity stretches the Y
        // domain far enough to make every other point NaN too.
        let points = series.filter { $0.value.isFinite }
        if points.isEmpty {
            // On "All" there is no longer range to widen to, so the advice would
            // be a dead end — the metric pickers offer every metric, logged or
            // not, so an empty all-time chart is reachable.
            if range == .all {
                ContentUnavailableView("Nothing logged yet", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView {
                    Label("No data in this range", systemImage: "calendar")
                } description: {
                    Text("Try a longer range.")
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(title(kind), point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.tint)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(title(kind), point.value)
                )
                .foregroundStyle(.tint)
                .symbolSize(points.count > 30 ? 12 : 40)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatValue(v, kind: kind))
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain(points))
            .frame(height: 220)
            .padding(.vertical, 8)
            .accessibilityLabel(title(kind))
        }
    }

    // MARK: - Summary rows

    @ViewBuilder
    private func summaryRows(points: [SeriesPoint], kind: SeriesKind, range: StatsRange) -> some View {
        let summary = StatsCalculator.summary(of: points)
        if summary.pointCount > 0 {
            if let latest = summary.latest {
                summaryRow("Latest", valueLabel(latest, kind: kind))
            }
            if let change = summary.change, summary.pointCount > 1 {
                summaryRow("Change (\(range.label))", changeLabel(change, kind: kind))
            }
            if summary.pointCount > 1, let rate = monthlyRate(points) {
                summaryRow("Rate", "\(changeLabel(rate, kind: kind))/mo")
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Change per 30 days across the visible range; nil when it can't be computed.
    private func monthlyRate(_ points: [SeriesPoint]) -> Double? {
        guard let first = points.first, let last = points.last else { return nil }
        let days = calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 0
        guard days > 0 else { return nil }
        return (last.value - first.value) / Double(days) * 30
    }

    // MARK: - Formatting

    private func title(_ kind: SeriesKind) -> String {
        switch kind {
        case .exercise(let metric): metric.label
        case .body(let metric): metric.label
        }
    }

    private func unitSuffix(_ kind: SeriesKind) -> String {
        switch kind {
        case .exercise: unitLabel
        case .body(.bodyWeight): unitLabel
        case .body(.calories): "kcal"
        case .body(.protein): "g"
        }
    }

    private func valueLabel(_ value: Double, kind: SeriesKind) -> String {
        "\(formatValue(value, kind: kind)) \(unitSuffix(kind))"
    }

    /// Compact formatting for axis ticks and summary values. A value that isn't
    /// a real number reads as no value.
    ///
    /// Whole numbers print through `%.0f` rather than `Int(_:)`, which traps on
    /// anything outside `Int` — an absurd logged weight carries all the way here
    /// through volume and 1RM, and a label is never worth a crash.
    private func formatValue(_ value: Double, kind: SeriesKind) -> String {
        guard value.isFinite else { return "—" }
        if case .exercise(.volume) = kind { return compactVolume(value) }
        switch kind {
        case .body(.calories), .body(.protein):
            return String(format: "%.0f", value.rounded())
        default:
            return value == floor(value) ? String(format: "%.0f", value) : String(format: "%.1f", value)
        }
    }

    private func changeLabel(_ change: Double, kind: SeriesKind) -> String {
        let magnitude = formatValue(abs(change), kind: kind)
        let sign = change > 0 ? "+" : (change < 0 ? "−" : "")
        return "\(sign)\(magnitude) \(unitSuffix(kind))"
    }

    /// A padded Y range that never has zero span — a flat or single-point series
    /// would otherwise make Charts divide by zero and emit NaN to CoreGraphics.
    /// Non-finite values are dropped first: `min()`/`max()` propagate a leading
    /// NaN, and `nan ... nan` is not a range a `ClosedRange` will form at all.
    private func yDomain(_ points: [SeriesPoint]) -> ClosedRange<Double> {
        let values = points.map(\.value).filter(\.isFinite)
        guard let lo = values.min(), let hi = values.max() else { return 0...1 }
        guard hi > lo else { return (lo - 1)...(hi + 1) }
        let pad = (hi - lo) * 0.1
        return (lo - pad)...(hi + pad)
    }

    private func compactVolume(_ value: Double) -> String {
        if value >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.0f", value)
    }
}

extension View {
    /// Aligns a grouped section header's leading edge with its section card and the
    /// navigation title, trimming iOS's default extra cell-content indentation.
    /// Pair with `.contentMargins(.horizontal, 16, for: .scrollContent)` on the List.
    ///
    /// Headers read as bold mixed-case subheadings rather than the system's small
    /// uppercase caption, so one rung of the type hierarchy — and one header
    /// treatment — holds across every tab, the Log's month headers included.
    func alignedSectionHeader() -> some View {
        font(.subheadline)
            .fontWeight(.bold)
            .textCase(nil)
            .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 16))
    }

    /// Matching alignment for a section footer's explanatory text.
    func alignedSectionFooter() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 12, trailing: 16))
    }
}

#Preview {
    let _ = PreviewData.sampleStatsHistory
    let _ = PreviewData.sampleBody
    return StatsView()
        .modelContainer(PreviewData.container)
}
