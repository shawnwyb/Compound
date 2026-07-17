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

    private var snapshot: [StatsWorkout] { StatsSnapshot.from(workouts) }
    private var tracked: [TrackedExercise] { StatsCalculator.trackedExercises(in: snapshot) }

    private var bodyData: [BodyPoint] {
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
        !StatsCalculator.bodySeries(metric: metric, in: bodyData).isEmpty
    }

    private var hasAnyExercise: Bool { !tracked.isEmpty }
    private var hasAnyBody: Bool { BodyMetric.allCases.contains(where: bodyHasData) }
    private var hasAnyData: Bool { hasAnyExercise || hasAnyBody }

    /// Selected exercise, defaulting to the most recent and healing if a chosen
    /// exercise no longer exists.
    private var resolvedExerciseID: UUID? {
        if let id = exerciseSelection, tracked.contains(where: { $0.id == id }) { return id }
        return tracked.first?.id
    }

    /// Selected body metric, defaulting to the first metric that has data.
    private var resolvedBodyMetric: BodyMetric {
        bodyMetricSelection ?? BodyMetric.allCases.first(where: bodyHasData) ?? .bodyWeight
    }

    private var liftsPoints: [SeriesPoint] {
        guard let id = resolvedExerciseID else { return [] }
        let all = StatsCalculator.exerciseSeries(exerciseID: id, metric: exerciseMetric, in: snapshot)
        return StatsCalculator.filter(all, range: liftsRange)
    }

    private var bodyPoints: [SeriesPoint] {
        let all = StatsCalculator.bodySeries(metric: resolvedBodyMetric, in: bodyData)
        return StatsCalculator.filter(all, range: bodyRange)
    }

    private var exerciseBinding: Binding<UUID?> {
        Binding(get: { resolvedExerciseID }, set: { exerciseSelection = $0 })
    }

    private var bodyMetricBinding: Binding<BodyMetric> {
        Binding(get: { resolvedBodyMetric }, set: { bodyMetricSelection = $0 })
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
                            Section {
                                overviewGrid
                            } header: {
                                Text("Overview").alignedSectionHeader()
                            }
                        }
                        if hasAnyExercise {
                            Section {
                                liftsSection
                            } header: {
                                Text("Lifts").alignedSectionHeader()
                            }
                        }
                        if hasAnyBody {
                            Section {
                                bodySection
                            } header: {
                                Text("Body").alignedSectionHeader()
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Overview

    private var overviewGrid: some View {
        HStack(spacing: 12) {
            statTile(title: "Workouts", value: "\(totals.workoutCount)")
            statTile(title: "Streak", value: "\(streak.current)d")
            statTile(title: "Last 7d", value: "\(streak.daysLast7)")
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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

    // MARK: - Lifts explorer

    @ViewBuilder
    private var liftsSection: some View {
        Picker("Exercise", selection: exerciseBinding) {
            ForEach(tracked) { exercise in
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
        chartView(points: liftsPoints, kind: kind)
        summaryRows(points: liftsPoints, kind: kind)
    }

    // MARK: - Body explorer

    @ViewBuilder
    private var bodySection: some View {
        Picker("Metric", selection: bodyMetricBinding) {
            ForEach(BodyMetric.allCases) { metric in
                Text(metric.label).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)

        rangePicker($bodyRange)

        let kind = SeriesKind.body(resolvedBodyMetric)
        chartView(points: bodyPoints, kind: kind)
        summaryRows(points: bodyPoints, kind: kind)
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
            .frame(height: 220)
            .padding(.vertical, 4)
            .accessibilityLabel(title(kind))
        }
    }

    // MARK: - Summary rows

    @ViewBuilder
    private func summaryRows(points: [SeriesPoint], kind: SeriesKind) -> some View {
        let summary = StatsCalculator.summary(of: points)
        if summary.pointCount > 0 {
            if let latest = summary.latest {
                summaryRow("Latest", valueLabel(latest, kind: kind))
            }
            if let change = summary.change, summary.pointCount > 1 {
                summaryRow("Change", changeLabel(change, kind: kind))
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
    func alignedSectionHeader() -> some View {
        listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 8, trailing: 16))
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
