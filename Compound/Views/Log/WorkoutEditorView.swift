import SwiftUI
import SwiftData

/// Edit a finished (or manually added) workout directly. Mutates only this
/// `Workout` and its child rows — never touches any `Routine`.
struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: Workout
    let isNew: Bool

    @State private var showPicker = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $workout.routineName)
                DatePicker(
                    "Date",
                    selection: $workout.date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                LabeledContent("Duration", value: TimeFormat.clock(workout.durationSeconds))
            } header: {
                Text("Details").alignedSectionHeader()
            }

            ForEach(workout.orderedExercises) { exercise in
                Section {
                    ForEach(exercise.orderedSets) { set in
                        WorkoutSetRow(set: set)
                    }
                    .onDelete { deleteSets(at: $0, in: exercise) }

                    Button {
                        addSet(to: exercise)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                } header: {
                    HStack {
                        Text(exercise.exerciseName)
                        Spacer()
                        Button("Remove", role: .destructive) {
                            removeExercise(exercise)
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                    .alignedSectionHeader()
                }
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationTitle(isNew ? "New Workout" : "Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                EditButton()
                Button("Done") { done() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showPicker) {
            WorkoutExercisePickerView(workout: workout)
        }
        .interactiveDismissDisabled(isNew)
    }

    private func cancel() {
        if isNew {
            context.delete(workout)
        }
        dismiss()
    }

    private func done() {
        if workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workout.routineName = "Workout"
        }
        if !isNew {
            workout.editedAt = .now
        }
        try? context.save()
        dismiss()
    }

    private func addSet(to exercise: WorkoutExercise) {
        let next = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        let last = exercise.orderedSets.last
        let entry = SetEntry(
            setNumber: next,
            reps: last?.reps ?? 0,
            weight: last?.weight ?? 0,
            completed: false
        )
        context.insert(entry)
        entry.workoutExercise = exercise
    }

    private func deleteSets(at offsets: IndexSet, in exercise: WorkoutExercise) {
        let ordered = exercise.orderedSets
        for index in offsets {
            context.delete(ordered[index])
        }
        renumberSets(in: exercise)
    }

    private func renumberSets(in exercise: WorkoutExercise) {
        for (index, set) in exercise.orderedSets.enumerated() {
            set.setNumber = index + 1
        }
    }

    private func removeExercise(_ exercise: WorkoutExercise) {
        context.delete(exercise)
        reindexExercises()
    }

    private func reindexExercises() {
        for (index, exercise) in workout.orderedExercises.enumerated() {
            exercise.position = index
        }
    }
}

/// One editable set row: number, weight, reps, completion.
private struct WorkoutSetRow: View {
    @Query private var settingsRows: [Settings]
    @Bindable var set: SetEntry

    private var unit: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.setNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            numberField(value: $set.weight, unit: unit, width: 66)
            intField(value: $set.reps, unit: "reps", width: 58)

            Spacer()

            Button {
                set.completed.toggle()
            } label: {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.completed ? "Mark incomplete" : "Mark complete")
        }
        .padding(.vertical, 2)
    }

    private func numberField(value: Binding<Double>, unit: String, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func intField(value: Binding<Int>, unit: String, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutEditorView(workout: PreviewData.sampleWorkout, isNew: false)
    }
    .modelContainer(PreviewData.container)
}
