import SwiftUI
import SwiftData

/// The Log tab: finished workouts grouped by month.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Environment(ActiveWorkout.self) private var activeWorkout
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var editingWorkout: Workout?
    @State private var editingIsNew = false

    /// Finished workouts only — the in-progress session gets its own card and
    /// never appears in the month history.
    private var finished: [Workout] {
        workouts.filter { !$0.isInProgress }
    }

    /// The single live workout, if one is running (surfaced for resume).
    private var inProgress: Workout? {
        workouts.first { $0.isInProgress }
    }

    private var sections: [MonthSection<Workout>] {
        LogGrouping.sections(from: finished, date: \.date)
    }

    var body: some View {
        NavigationStack {
            Group {
                if finished.isEmpty && inProgress == nil {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "calendar")
                    } description: {
                        Text("Finish a workout from Routines, or add one here.")
                    } actions: {
                        Button("Add Workout") { addWorkout() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if let inProgress {
                            Section {
                                InProgressCard(workout: inProgress) { resume(inProgress) }
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }
                        ForEach(sections, id: \.monthStart) { section in
                            Section {
                                ForEach(section.items) { workout in
                                    WorkoutRow(workout: workout)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .background {
                                            NavigationLink(value: workout) { EmptyView() }
                                                .opacity(0)
                                        }
                                }
                                .onDelete { offsets in
                                    delete(at: offsets, in: section.items)
                                }
                            } header: {
                                HStack {
                                    Text(section.title)
                                    Spacer()
                                    Text(countLabel(section.count))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                                .textCase(nil)
                                .fontWeight(.bold)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0, for: .scrollContent)
                    .listSectionSpacing(.compact)
                }
            }
            .navigationTitle("Log")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutEditorView(workout: workout, isNew: false)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !finished.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addWorkout() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Workout")
                }
            }
            .sheet(item: $editingWorkout) { workout in
                NavigationStack {
                    WorkoutEditorView(workout: workout, isNew: editingIsNew)
                }
            }
        }
    }

    /// Re-open the in-progress workout: maximize it if it's the active one,
    /// otherwise adopt it (e.g. resuming after relaunch).
    private func resume(_ workout: Workout) {
        if activeWorkout.workout?.id == workout.id {
            activeWorkout.maximize()
        } else {
            activeWorkout.start(workout)
        }
    }

    private func countLabel(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }

    private func addWorkout() {
        // Manually added Log entries are finished by definition.
        let workout = Workout(routineName: "Workout", date: .now, startedAt: .now, finishedAt: .now)
        context.insert(workout)
        editingIsNew = true
        editingWorkout = workout
    }

    private func delete(at offsets: IndexSet, in items: [Workout]) {
        for index in offsets {
            context.delete(items[index])
        }
    }
}

/// A distinct, tinted card for the single live workout — tap to resume it.
private struct InProgressCard: View {
    let workout: Workout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("In Progress", systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                    ElapsedTimeText(since: workout.startedAt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(workout.routineName.isEmpty ? "Workout" : workout.routineName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Tap to resume")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(workout.routineName.isEmpty ? "Workout" : workout.routineName)
                    .font(.headline)
                Spacer()
                Text("\(minutes) min")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Text(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !workout.orderedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(workout.orderedExercises) { exercise in
                        Text("\(exercise.sets.count)× \(exercise.exerciseName)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
    }

    /// Session length, rounded to whole minutes.
    private var minutes: Int {
        Int((Double(workout.durationSeconds) / 60).rounded())
    }
}

#Preview {
    LogView()
        .environment(ActiveWorkout())
        .modelContainer(PreviewData.container)
}
