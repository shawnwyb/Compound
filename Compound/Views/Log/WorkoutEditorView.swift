import SwiftUI
import SwiftData

/// Edit a finished (or manually added) workout directly. Mutates only this
/// `Workout` and its child rows — never touches any `Routine`.
struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: Workout
    let isNew: Bool

    @Query private var settingsRows: [Settings]
    @State private var sheet: EditorSheet?

    private var unit: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    private enum EditorSheet: Identifiable {
        case addExercise
        case replace(WorkoutExercise)
        case reorder

        var id: String {
            switch self {
            case .addExercise: "add"
            case .replace(let exercise): exercise.id.uuidString
            case .reorder: "reorder"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $workout.routineName)
                DatePicker("Start time", selection: startBinding, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End time", selection: endBinding, displayedComponents: [.date, .hourAndMinute])
                TextField("Notes", text: $workout.notes, axis: .vertical)
            } header: {
                Text("Details").alignedSectionHeader()
            }

            ForEach(workout.orderedExercises) { exercise in
                Section {
                    ForEach(exercise.orderedSets) { set in
                        WorkoutSetRow(set: set, unit: unit)
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
                        Menu {
                            Button {
                                sheet = .reorder
                            } label: {
                                Label("Reorder", systemImage: "arrow.up.arrow.down")
                            }
                            .disabled(workout.orderedExercises.count < 2)

                            Button {
                                sheet = .replace(exercise)
                            } label: {
                                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Button(role: .destructive) {
                                removeExercise(exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                        .textCase(nil)
                    }
                    .alignedSectionHeader()
                }
            }

            Section {
                Button {
                    sheet = .addExercise
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { done() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $sheet) { active in
            switch active {
            case .addExercise:
                WorkoutExercisePickerView(workout: workout)
            case .replace(let exercise):
                SingleExercisePicker(
                    title: "Replace Exercise",
                    blockedIDs: blockedIDs(excluding: exercise),
                    currentID: exercise.exercise?.id
                ) { chosen in
                    exercise.exercise = chosen
                    exercise.exerciseName = chosen.name
                }
            case .reorder:
                ReorderExercisesView(workout: workout)
            }
        }
        .interactiveDismissDisabled(isNew)
    }

    // MARK: - Start / end time bindings

    /// Editing the start keeps the end fixed and recomputes the duration.
    private var startBinding: Binding<Date> {
        Binding(
            get: { workout.startedAt },
            set: { newStart in
                let end = workout.startedAt.addingTimeInterval(Double(workout.durationSeconds))
                workout.startedAt = newStart
                workout.date = newStart
                workout.durationSeconds = max(0, Int(end.timeIntervalSince(newStart)))
            }
        )
    }

    /// Editing the end keeps the start fixed and recomputes the duration.
    private var endBinding: Binding<Date> {
        Binding(
            get: { workout.startedAt.addingTimeInterval(Double(workout.durationSeconds)) },
            set: { newEnd in
                workout.durationSeconds = max(0, Int(newEnd.timeIntervalSince(workout.startedAt)))
            }
        )
    }

    // MARK: - Save / cancel

    private func cancel() {
        if isNew { context.delete(workout) }
        dismiss()
    }

    private func done() {
        if workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workout.routineName = "Workout"
        }
        // A set with logged reps or weight counts as performed — no manual toggle.
        for exercise in workout.exercises {
            for set in exercise.sets {
                set.completed = set.reps > 0 || set.weight > 0
            }
        }
        if !isNew { workout.editedAt = .now }
        try? context.save()
        dismiss()
    }

    // MARK: - Sets

    private func addSet(to exercise: WorkoutExercise) {
        let last = exercise.orderedSets.last
        insertSet(reps: last?.reps ?? 0, weight: last?.weight ?? 0, completed: false, in: exercise)
    }

    private func insertSet(reps: Int, weight: Double, completed: Bool, in exercise: WorkoutExercise) {
        let next = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        let entry = SetEntry(setNumber: next, reps: reps, weight: weight, completed: completed)
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

    // MARK: - Exercises

    private func removeExercise(_ exercise: WorkoutExercise) {
        context.delete(exercise)
        reindexExercises()
    }

    private func reindexExercises() {
        for (index, exercise) in workout.orderedExercises.enumerated() {
            exercise.position = index
        }
    }

    private func blockedIDs(excluding exercise: WorkoutExercise) -> Set<UUID> {
        var ids = Set(workout.exercises.compactMap { $0.exercise?.id })
        if let currentID = exercise.exercise?.id { ids.remove(currentID) }
        return ids
    }
}

/// One editable set row: number, weight, reps, and a menu to duplicate or delete.
private struct WorkoutSetRow: View {
    @Bindable var set: SetEntry
    let unit: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.setNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            numberField(value: $set.weight, unit: unit, width: 66)
            intField(value: $set.reps, unit: "reps", width: 58)

            Spacer()
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

/// A focused drag-to-reorder screen for the workout's exercises.
private struct ReorderExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(workout.orderedExercises) { exercise in
                    Text(exercise.exerciseName)
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func move(_ offsets: IndexSet, to destination: Int) {
        var ordered = workout.orderedExercises
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, exercise) in ordered.enumerated() {
            exercise.position = index
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutEditorView(workout: PreviewData.sampleWorkout, isNew: false)
    }
    .modelContainer(PreviewData.container)
}
