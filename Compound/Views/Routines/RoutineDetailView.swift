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

    @State private var session: WorkoutSession?
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
                ForEach(routine.orderedExercises) { item in
                    ExerciseEditRow(routineExercise: item)
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
                session = WorkoutHistory.makeSession(for: routine, context: context)
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
        .fullScreenCover(item: $session) { session in
            WorkoutSessionView(session: session)
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

#Preview {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .modelContainer(PreviewData.container)
}
