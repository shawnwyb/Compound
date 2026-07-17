import SwiftUI
import SwiftData

/// The Log tab: finished workouts grouped by month.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]

    @State private var editingWorkout: Workout?
    @State private var editingIsNew = false

    private var sections: [MonthSection<Workout>] {
        LogGrouping.sections(from: workouts, date: \.date)
    }

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
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
                        ForEach(sections, id: \.monthStart) { section in
                            Section {
                                ForEach(section.items) { workout in
                                    WorkoutRow(workout: workout)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
                    if !workouts.isEmpty { EditButton() }
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

    private func countLabel(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }

    private func addWorkout() {
        let workout = Workout(routineName: "Workout", date: .now, startedAt: .now)
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

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                .font(.caption)
                .foregroundStyle(.secondary)

            if !workout.orderedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(workout.orderedExercises) { exercise in
                        Text("\(exercise.sets.count)× \(exercise.exerciseName)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Session length, rounded to whole minutes.
    private var minutes: Int {
        Int((Double(workout.durationSeconds) / 60).rounded())
    }
}

#Preview {
    LogView()
        .modelContainer(PreviewData.container)
}
