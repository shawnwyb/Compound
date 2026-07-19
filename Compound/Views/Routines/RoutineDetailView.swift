import SwiftUI
import SwiftData

/// Editable detail for a routine: rename, adjust target sets, and add / remove /
/// reorder exercises inline, then start a workout. Routine-level actions
/// (reorder, duplicate, delete) live in the toolbar menu.
struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var routine: Routine
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]

    @State private var activeWorkout: Workout?
    @State private var showPicker = false
    @State private var showDeleteConfirm = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                TextField("Routine name", text: $routine.name)
            } header: {
                Text("Name").alignedSectionHeader()
            }

            Section {
                NavigationLink {
                    PrefillOptionsView(routine: routine)
                } label: {
                    LabeledContent(
                        "Starting Weights & Reps",
                        value: routine.prefillFromRoutine ? "Routine" : "Latest"
                    )
                }
            }

            Section {
                ForEach(routine.orderedExercises) { item in
                    NavigationLink {
                        RoutineExerciseDetailView(routineExercise: item, routine: routine)
                    } label: {
                        RoutineExerciseSummaryRow(item: item)
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button {
                    showPicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Exercises").alignedSectionHeader()
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .environment(\.editMode, $editMode)
        .navigationTitle(routine.name.isEmpty ? "Untitled" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                activeWorkout = WorkoutHistory.startWorkout(for: routine, context: context)
            } label: {
                Text("Start Workout")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(routine.orderedExercises.isEmpty)
            .padding()
            .background(.bar)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if editMode.isEditing {
                    Button("Done") { withAnimation { editMode = .inactive } }
                } else {
                    Menu {
                        Button {
                            withAnimation { editMode = .active }
                        } label: {
                            Label("Reorder", systemImage: "arrow.up.arrow.down")
                        }
                        .disabled(routine.orderedExercises.count < 2)

                        Button {
                            duplicate()
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Routine", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView(routine: routine)
        }
        .fullScreenCover(item: $activeWorkout) { workout in
            NavigationStack {
                WorkoutEditorView(workout: workout, isNew: false)
            }
        }
        .confirmationDialog(
            "Delete this routine?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Routine", role: .destructive) { deleteRoutine() }
        } message: {
            Text("This can't be undone. Your logged workouts are kept.")
        }
    }

    private func deleteExercises(_ offsets: IndexSet) {
        let ordered = routine.orderedExercises
        for index in offsets {
            context.delete(ordered[index])
        }
        reindex()
    }

    private func moveExercises(_ offsets: IndexSet, to destination: Int) {
        var ordered = routine.orderedExercises
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.position = index
        }
    }

    private func reindex() {
        for (index, item) in routine.orderedExercises.enumerated() {
            item.position = index
        }
    }

    private func duplicate() {
        let baseName = routine.name.isEmpty ? "Untitled" : routine.name
        let copy = Routine(name: "\(baseName) Copy", sortOrder: routines.count)
        context.insert(copy)
        for (index, item) in routine.orderedExercises.enumerated() {
            let newItem = RoutineExercise(
                exercise: item.exercise,
                targetSets: item.targetSets,
                position: index
            )
            context.insert(newItem)
            newItem.routine = copy
        }
        dismiss()
    }

    private func deleteRoutine() {
        context.delete(routine)
        dismiss()
    }
}

/// Full-screen selector for a routine's prefill source, with the fallback rule
/// spelled out in the footer.
private struct PrefillOptionsView: View {
    @Bindable var routine: Routine

    var body: some View {
        List {
            Section {
                optionRow(
                    title: "Latest",
                    detail: "The most recent time you did each exercise, in any routine.",
                    isOn: !routine.prefillFromRoutine
                ) { routine.prefillFromRoutine = false }

                optionRow(
                    title: "Routine",
                    detail: "The most recent time you ran this routine. Falls back to Latest until you’ve run it once.",
                    isOn: routine.prefillFromRoutine
                ) { routine.prefillFromRoutine = true }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationTitle("Starting Weights & Reps")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func optionRow(
        title: String,
        detail: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .modelContainer(PreviewData.container)
}
