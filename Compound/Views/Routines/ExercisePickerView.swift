import SwiftUI
import SwiftData

/// Multi-select picker to add exercises to a routine, grouped by muscle group.
/// Exercises already in the routine are hidden to avoid duplicates.
struct ExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var routine: Routine
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]
    /// Queried directly so deleting a library entry updates this list once.
    /// Reading `group.exercises` and also mutating that array double-fires the
    /// List diff and crashes UICollectionView.
    @Query private var library: [Exercise]

    @State private var selectedIDs: Set<UUID> = []
    @State private var search = ""
    @State private var showNewExercise = false
    @State private var pendingDelete: Exercise?

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    let exercises = available(in: group)
                    if !exercises.isEmpty {
                        Section {
                            ForEach(exercises, id: \.id) { exercise in
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
                                .swipeToDeleteCustomExercise(exercise, pending: $pendingDelete)
                            }
                        } header: {
                            Text(group.name).alignedSectionHeader()
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(16)
            .animation(nil, value: library.count)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            // Confirming the selection lives at the bottom, on the same
            // prominent button the routine screen uses to start a workout. In
            // the toolbar it sat against the ✛ and the two merged into one
            // capsule reading "✛ Add" — two different adds, touching.
            .safeAreaInset(edge: .bottom) {
                if !selectedIDs.isEmpty {
                    Button {
                        addSelected()
                    } label: {
                        Text(addLabel)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                    .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
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
            .deleteCustomExerciseDialog(pending: $pendingDelete) { deletedID in
                selectedIDs.remove(deletedID)
            }
        }
    }

    /// Counts what's ticked, so the button says what it will do rather than
    /// making you remember how many rows you tapped on the way down the list.
    private var addLabel: String {
        selectedIDs.count == 1 ? "Add 1 Exercise" : "Add \(selectedIDs.count) Exercises"
    }

    private var existingExerciseIDs: Set<UUID> {
        Set(routine.exercises.compactMap { $0.exercise?.id })
    }

    private func available(in group: MuscleGroup) -> [Exercise] {
        library
            .filter { $0.group?.id == group.id }
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
        let chosen = library.filter { selectedIDs.contains($0.id) }
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
