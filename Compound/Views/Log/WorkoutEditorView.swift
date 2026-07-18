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
    @Query private var routines: [Routine]
    @State private var sheet: EditorSheet?
    /// Set when the workout is deleted (or a new one cancelled) so the
    /// finalize-on-disappear pass doesn't touch a discarded object.
    @State private var removed = false

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
                    ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.id) { index, set in
                        WorkoutSetRow(
                            set: set,
                            unit: unit,
                            ghostWeight: index > 0 ? exercise.orderedSets[index - 1].weight : nil,
                            ghostReps: index > 0 ? exercise.orderedSets[index - 1].reps : nil
                        )
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            saveAsRoutine()
                        } label: {
                            Label("Save as Routine", systemImage: "square.and.arrow.down")
                        }

                        Button(role: .destructive) {
                            deleteWorkout()
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onDisappear { finalizeIfNeeded() }
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
        removed = true
        if isNew { context.delete(workout) }
        dismiss()
    }

    /// Commit edits when leaving, unless the workout was deleted or cancelled.
    private func finalizeIfNeeded() {
        guard !removed else { return }
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
    }

    private func deleteWorkout() {
        removed = true
        context.delete(workout)
        dismiss()
    }

    /// Create a new routine template from this workout's exercises, using each
    /// exercise's set count as the target. Reps/weight aren't stored on routines.
    private func saveAsRoutine() {
        let name = workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let routine = Routine(name: name.isEmpty ? "Workout" : name, sortOrder: routines.count)
        context.insert(routine)
        for (index, exercise) in workout.orderedExercises.enumerated() {
            let planned = RoutineExercise(
                exercise: exercise.exercise,
                targetSets: max(1, exercise.sets.count),
                position: index
            )
            context.insert(planned)
            planned.routine = routine
        }
    }

    // MARK: - Sets

    private func addSet(to exercise: WorkoutExercise) {
        // Empty on purpose — the row shows the previous set's values as ghost text.
        insertSet(reps: 0, weight: 0, completed: false, in: exercise)
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

/// One editable log set: the shared borderless layout. The circle is a plain
/// indicator (filled once the set has data); completion is finalized on save.
private struct WorkoutSetRow: View {
    @Bindable var set: SetEntry
    let unit: String
    /// Previous set's values, shown as gray "ghost" placeholders until this set
    /// is filled in.
    let ghostWeight: Double?
    let ghostReps: Int?

    var body: some View {
        SetInputRow(
            setNumber: set.setNumber,
            unit: unit,
            ghostWeight: ghostSetNumber(ghostWeight ?? 0),
            ghostReps: ghostSetNumber(Double(ghostReps ?? 0)),
            initialWeight: set.weight != 0 ? formattedSetNumber(set.weight) : "",
            initialReps: set.reps != 0 ? "\(set.reps)" : "",
            note: $set.note,
            completed: set.reps > 0 || set.weight > 0,
            onWeightChange: { set.weight = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 },
            onRepsChange: { set.reps = Int($0.filter(\.isNumber)) ?? 0 }
        )
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
