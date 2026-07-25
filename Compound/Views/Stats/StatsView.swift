import SwiftUI
import SwiftData
import Charts

/// Progress tab: a consistency snapshot plus two progression explorers — one for
/// lifts (an exercise's top set / est. 1RM / volume over time) and one for body
/// metrics (bodyweight / calories / protein). Each explorer shares the same
/// picker → range → line chart → summary layout.
struct StatsView: View {
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

    var body: some View {
        // One pass over the store per render. These values used to be computed
        // properties, so `body` re-walked the whole history for each read —
        // faulting every exercise and set back in a dozen times over.
        let digest = StatsDigest(workouts: workouts, entries: dailyEntries)

        NavigationStack {
            Group {
                if !digest.hasAnyData {
                    ContentUnavailableView {
                        Label("No Stats Yet", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Finish a few workouts, or log your bodyweight, and your progress will show up here.")
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
            .navigationTitle("Stats")
        }
    }

    // MARK: - Overview

    private func overviewGrid(_ digest: StatsDigest) -> some View {
        HStack(spacing: 8) {
            statTile(title: "Workouts", value: "\(digest.totals.workoutCount)")
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
        chartView(points: points, kind: kind)
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
        chartView(points: points, kind: kind)
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
    private func chartView(points: [SeriesPoint], kind: SeriesKind) -> some View {
        if points.isEmpty {
            ContentUnavailableView {
                Label("No data in this range", systemImage: "calendar")
            } description: {
                Text("Try a longer range, or log more of this metric.")
            }
            .frame(maxWidth: .infinity)
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

    /// Compact formatting for axis ticks and summary values.
    private func formatValue(_ value: Double, kind: SeriesKind) -> String {
        if case .exercise(.volume) = kind { return compactVolume(value) }
        switch kind {
        case .body(.calories), .body(.protein):
            return "\(Int(value.rounded()))"
        default:
            return value == floor(value) ? "\(Int(value))" : String(format: "%.1f", value)
        }
    }

    private func changeLabel(_ change: Double, kind: SeriesKind) -> String {
        let magnitude = formatValue(abs(change), kind: kind)
        let sign = change > 0 ? "+" : (change < 0 ? "−" : "")
        return "\(sign)\(magnitude) \(unitSuffix(kind))"
    }

    /// A padded Y range that never has zero span — a flat or single-point series
    /// would otherwise make Charts divide by zero and emit NaN to CoreGraphics.
    private func yDomain(_ points: [SeriesPoint]) -> ClosedRange<Double> {
        let values = points.map(\.value)
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
            return "\(Int(value))"
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
