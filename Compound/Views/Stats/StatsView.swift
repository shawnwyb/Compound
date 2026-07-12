import SwiftUI
import SwiftData
import Charts

/// Progress tab: totals, streaks, charts, muscle-group breakdown, and PRs.
struct StatsView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    private var snapshot: [StatsWorkout] {
        StatsSnapshot.from(workouts)
    }

    private var totals: StatsTotals {
        StatsCalculator.totals(in: snapshot)
    }

    private var streak: StreakStats {
        StatsCalculator.streak(in: snapshot)
    }

    private var groups: [GroupVolume] {
        StatsCalculator.groupBreakdown(in: snapshot)
    }

    private var prs: [PersonalRecord] {
        StatsCalculator.personalRecords(in: snapshot)
    }

    private var volumeSeries: [DailyVolume] {
        StatsCalculator.volumePerDay(in: snapshot)
    }

    private var workoutSeries: [DailyWorkoutCount] {
        StatsCalculator.workoutsPerDay(in: snapshot)
    }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Stats Yet", systemImage: "chart.bar.fill")
                    } description: {
                        Text("Finish a few workouts and your progress will show up here.")
                    }
                } else {
                    List {
                        Section("Overview") {
                            overviewGrid
                        }

                        if volumeSeries.count >= 1 {
                            Section("Volume") {
                                volumeChart
                                    .frame(height: 180)
                                    .padding(.vertical, 4)
                            }
                        }

                        if workoutSeries.count >= 1 {
                            Section("Workouts") {
                                workoutsChart
                                    .frame(height: 160)
                                    .padding(.vertical, 4)
                            }
                        }

                        if !groups.isEmpty {
                            Section("Muscle Groups") {
                                groupChart
                                    .frame(height: max(CGFloat(groups.count) * 36, 80))
                                    .padding(.vertical, 4)

                                ForEach(groups) { group in
                                    HStack {
                                        Text(group.groupName)
                                        Spacer()
                                        Text(volumeLabel(group.volume))
                                            .foregroundStyle(.secondary)
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                        Text(setLabel(group.setCount))
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        if !prs.isEmpty {
                            Section("Personal Records") {
                                ForEach(prs) { pr in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pr.exerciseName)
                                            .font(.headline)
                                        Text(
                                            "Best \(weightLabel(pr.bestWeight)) · Est. 1RM \(weightLabel(pr.estimatedOneRepMax))"
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }

    private var overviewGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statTile(title: "Workouts", value: "\(totals.workoutCount)")
                statTile(title: "Volume", value: compactVolume(totals.totalVolume))
            }
            HStack(spacing: 12) {
                statTile(title: "Sets", value: "\(totals.completedSetCount)")
                statTile(title: "Days", value: "\(totals.trainingDayCount)")
            }
            HStack(spacing: 12) {
                statTile(title: "Streak", value: "\(streak.current)d")
                statTile(title: "Best streak", value: "\(streak.longest)d")
            }
            HStack(spacing: 12) {
                statTile(title: "Last 7 days", value: "\(streak.daysLast7)")
                statTile(title: "Last 30 days", value: "\(streak.daysLast30)")
            }
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var volumeChart: some View {
        Chart(volumeSeries) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value("Volume", point.volume)
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
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(compactVolume(v))
                    }
                }
            }
        }
        .accessibilityLabel("Volume by day")
    }

    private var workoutsChart: some View {
        Chart(workoutSeries) { point in
            BarMark(
                x: .value("Day", point.day, unit: .day),
                y: .value("Workouts", point.count)
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
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
        }
        .accessibilityLabel("Workouts by day")
    }

    private var groupChart: some View {
        Chart(groups) { group in
            BarMark(
                x: .value("Volume", group.volume),
                y: .value("Group", group.groupName)
            )
            .foregroundStyle(.tint)
        }
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(compactVolume(v))
                    }
                }
            }
        }
        .accessibilityLabel("Volume by muscle group")
    }

    private func volumeLabel(_ value: Double) -> String {
        "\(compactVolume(value)) lb"
    }

    private func weightLabel(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value)) lb"
        }
        return String(format: "%.1f lb", value)
    }

    private func setLabel(_ count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
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
    let _ = PreviewData.sampleWorkout
    StatsView()
        .modelContainer(PreviewData.container)
}
