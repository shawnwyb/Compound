import SwiftUI
import SwiftData

/// Multi-select picker to add exercises to a routine, grouped by muscle group.
/// Exercises already in the routine are hidden to avoid duplicates.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]

    @State private var selectedIDs: Set<UUID> = []
    @State private var search = ""
    @State private var showNewExercise = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    let exercises = available(in: group)
                    if !exercises.isEmpty {
                        Section {
                            ForEach(exercises) { exercise in
                                Button {
                                    toggle(exercise)
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedIDs.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(group.name).alignedSectionHeader()
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(16)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addSelected() }
                        .disabled(selectedIDs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewExercise = true
                    } label: {
                        Label("New Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewExercise) {
                NewExerciseView { created in
                    // Ticked on arrival, and the search cleared so it isn't
                    // filtered straight back out of the list behind this sheet.
                    search = ""
                    selectedIDs.insert(created.id)
                }
            }
        }
    }

    private var existingExerciseIDs: Set<UUID> {
        Set(routine.exercises.compactMap { $0.exercise?.id })
    }

    private func available(in group: MuscleGroup) -> [Exercise] {
        group.exercises
            .filter { !existingExerciseIDs.contains($0.id) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }

    private func addSelected() {
        var position = routine.exercises.count
        let chosen = groups
            .flatMap { $0.exercises }
            .filter { selectedIDs.contains($0.id) }
        for exercise in chosen {
            let item = RoutineExercise(exercise: exercise, targetSets: 3, position: position)
            context.insert(item)
            // Link through the parent: assigning `item.routine` updates the store
            // but doesn't notify observers of `routine.exercises`, so the open
            // editor would keep showing a stale (empty) list.
            routine.exercises.append(item)
            position += 1
        }
        dismiss()
    }
}

#Preview {
    ExercisePickerView(routine: PreviewData.sampleRoutine)
        .modelContainer(PreviewData.container)
}
