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
                                    NavigationLink(value: workout) {
                                        WorkoutRow(workout: workout)
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
                                .alignedSectionHeader()
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
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
        VStack(alignment: .leading, spacing: 2) {
            Text(workout.routineName.isEmpty ? "Workout" : workout.routineName)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        let day = workout.date.formatted(.dateTime.month(.abbreviated).day())
        let duration = TimeFormat.clock(workout.durationSeconds)
        let exercises = workout.exercises.count
        let exerciseLabel = exercises == 1 ? "1 exercise" : "\(exercises) exercises"
        let sets = workout.completedSetCount
        let setLabel = sets == 1 ? "1 set" : "\(sets) sets"
        return "\(day) · \(duration) · \(exerciseLabel) · \(setLabel)"
    }
}

#Preview {
    LogView()
        .modelContainer(PreviewData.container)
}
