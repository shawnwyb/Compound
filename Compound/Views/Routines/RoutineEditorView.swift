import SwiftUI
import SwiftData

/// Create or edit a routine: name, exercises, target sets, order.
/// Operates directly on the live SwiftData object (autosaved). Cancelling a
/// brand-new routine deletes it; cancelling an existing one keeps prior edits.
struct RoutineEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine
    let isNew: Bool

    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle(isNew ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button("Done") { done() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(routine: routine)
            }
        }
    }

    private func cancel() {
        if isNew {
            context.delete(routine)
        }
        dismiss()
    }

    private func done() {
        if routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            routine.name = "New Routine"
        }
        try? context.save()
        dismiss()
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
}

/// Row with the exercise name/group and a stepper for its target set count.
private struct ExerciseEditRow: View {
    @Bindable var routineExercise: RoutineExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(routineExercise.exercise?.name ?? "Deleted exercise")
            if let group = routineExercise.exercise?.group?.name {
                Text(group)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Stepper(value: $routineExercise.targetSets, in: 1...20) {
                Text("\(routineExercise.targetSets) sets")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RoutineEditorView(routine: PreviewData.sampleRoutine, isNew: false)
        .modelContainer(PreviewData.container)
}
