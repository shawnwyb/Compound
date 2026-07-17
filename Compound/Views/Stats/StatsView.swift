import SwiftUI
import SwiftData
import Charts

/// Progress tab: a focused progression explorer. Pick one metric — an exercise
/// or a body measure — and see its trend as a single line chart, with a compact
/// motivational header above it.
struct StatsView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Query(sort: \DailyEntry.date) private var dailyEntries: [DailyEntry]
    @Query private var settingsRows: [Settings]

    /// Which metric the chart is showing. `nil` until the user picks one — the
    /// view resolves a sensible default (see `resolvedSelection`).
    @State private var selection: MetricSelection?
    @State private var exerciseMetric: ExerciseMetric = .topSetWeight
    @State private var range: StatsRange = .month3

    /// The chart's subject: a tracked exercise or a body metric.
    private enum MetricSelection: Hashable {
        case exercise(UUID)
        case body(BodyMetric)
    }

    // MARK: - Derived data

    private var snapshot: [StatsWorkout] { StatsSnapshot.from(workouts) }
    private var tracked: [TrackedExercise] { StatsCalculator.trackedExercises(in: snapshot) }

    private var bodyPoints: [BodyPoint] {
        dailyEntries.map {
            BodyPoint(date: $0.date, bodyWeight: $0.bodyWeight, calories: $0.calories, protein: $0.protein)
        }
    }

    private var totals: StatsTotals { StatsCalculator.totals(in: snapshot) }
    private var streak: StreakStats { StatsCalculator.streak(in: snapshot) }

    private var unitLabel: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    private func bodyHasData(_ metric: BodyMetric) -> Bool {
        !StatsCalculator.bodySeries(metric: metric, in: bodyPoints).isEmpty
    }

    private var hasAnyData: Bool {
        !tracked.isEmpty || BodyMetric.allCases.contains(where: bodyHasData)
    }

    /// The effective selection, defaulting to the most recent exercise (or the
    /// first body metric that has data) and healing if a selected exercise no
    /// longer exists.
    private var resolvedSelection: MetricSelection {
        if let selection {
            if case .exercise(let id) = selection, !tracked.contains(where: { $0.id == id }) {
                return defaultSelection
            }
            return selection
        }
        return defaultSelection
    }

    private var defaultSelection: MetricSelection {
        if let first = tracked.first { return .exercise(first.id) }
        if let metric = BodyMetric.allCases.first(where: bodyHasData) { return .body(metric) }
        return .body(.bodyWeight)
    }

    private var selectionBinding: Binding<MetricSelection> {
        Binding(get: { resolvedSelection }, set: { selection = $0 })
    }

    private var points: [SeriesPoint] {
        let all: [SeriesPoint]
        switch resolvedSelection {
        case .exercise(let id):
            all = StatsCalculator.exerciseSeries(exerciseID: id, metric: exerciseMetric, in: snapshot)
        case .body(let metric):
            all = StatsCalculator.bodySeries(metric: metric, in: bodyPoints)
        }
        return StatsCalculator.filter(all, range: range)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !hasAnyData {
                    ContentUnavailableView {
                        Label("No Stats Yet", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Finish a few workouts, or log your bodyweight, and your progress will show up here.")
                    }
                } else {
                    List {
                        if !workouts.isEmpty {
                            Section("Overview") { overviewGrid }
                        }
                        Section("Progress") { chartSection }
                        summarySection
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Overview header

    private var overviewGrid: some View {
        HStack(spacing: 12) {
            statTile(title: "Workouts", value: "\(totals.workoutCount)")
            statTile(title: "Streak", value: "\(streak.current)d")
            statTile(title: "Last 7d", value: "\(streak.daysLast7)")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartSection: some View {
        Picker("Metric", selection: selectionBinding) {
            if !tracked.isEmpty {
                Section("Exercises") {
                    ForEach(tracked) { exercise in
                        Text(exercise.name).tag(MetricSelection.exercise(exercise.id))
                    }
                }
            }
            Section("Body") {
                ForEach(BodyMetric.allCases) { metric in
                    Text(metric.label).tag(MetricSelection.body(metric))
                }
            }
        }
        .pickerStyle(.navigationLink)

        if case .exercise = resolvedSelection {
            Picker("Measure", selection: $exerciseMetric) {
                ForEach(ExerciseMetric.allCases) { metric in
                    Text(metric.label).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
        }

        Picker("Range", selection: $range) {
            ForEach(StatsRange.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)

        chart
            .frame(height: 220)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private var chart: some View {
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
                    y: .value(seriesTitle, point.value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.tint)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(seriesTitle, point.value)
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
                            Text(axisValue(v))
                        }
                    }
                }
            }
            .accessibilityLabel(seriesTitle)
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        let summary = StatsCalculator.summary(of: points)
        if summary.pointCount > 0 {
            Section("Summary") {
                if let latest = summary.latest {
                    summaryRow("Latest", valueLabel(latest))
                }
                if let best = summary.best {
                    summaryRow("Best", valueLabel(best))
                }
                if let change = summary.change, summary.pointCount > 1 {
                    summaryRow("Change", changeLabel(change))
                }
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

    // MARK: - Formatting

    /// Human title for the currently selected series (used as the chart Y label).
    private var seriesTitle: String {
        switch resolvedSelection {
        case .exercise: exerciseMetric.label
        case .body(let metric): metric.label
        }
    }

    /// Unit suffix for the selected series' values.
    private var unitSuffix: String {
        switch resolvedSelection {
        case .exercise: unitLabel
        case .body(.bodyWeight): unitLabel
        case .body(.calories): "kcal"
        case .body(.protein): "g"
        }
    }

    /// Formats a raw value with its unit for summary rows.
    private func valueLabel(_ value: Double) -> String {
        "\(axisValue(value)) \(unitSuffix)"
    }

    /// Compact formatting for axis ticks and values.
    private func axisValue(_ value: Double) -> String {
        if case .exercise = resolvedSelection, exerciseMetric == .volume {
            return compactVolume(value)
        }
        switch resolvedSelection {
        case .body(.calories), .body(.protein):
            return "\(Int(value.rounded()))"
        default:
            return value == floor(value) ? "\(Int(value))" : String(format: "%.1f", value)
        }
    }

    private func changeLabel(_ change: Double) -> String {
        let magnitude = axisValue(abs(change))
        let sign = change > 0 ? "+" : (change < 0 ? "−" : "")
        return "\(sign)\(magnitude) \(unitSuffix)"
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

#Preview {
    let _ = PreviewData.sampleStatsHistory
    let _ = PreviewData.sampleBody
    return StatsView()
        .modelContainer(PreviewData.container)
}
