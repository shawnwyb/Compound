import SwiftUI
import SwiftData

/// Multi-select picker to add exercises to a finished workout, grouped by
/// muscle group. Exercises already in the workout are hidden.
struct WorkoutExercisePickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var workout: Workout
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]
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
            // Confirming the selection sits at the bottom rather than in the
            // toolbar, where it merged with the ✛ into one "✛ Add" capsule.
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
                    search = ""
                    selectedIDs.insert(created.id)
                }
            }
            .deleteCustomExerciseDialog(pending: $pendingDelete) { deletedID in
                selectedIDs.remove(deletedID)
            }
        }
    }

    private var addLabel: String {
        selectedIDs.count == 1 ? "Add 1 Exercise" : "Add \(selectedIDs.count) Exercises"
    }

    private var existingExerciseIDs: Set<UUID> {
        Set(workout.exercises.compactMap { $0.exercise?.id })
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
        var position = workout.exercises.count
        let chosen = library.filter { selectedIDs.contains($0.id) }
        for exercise in chosen {
            let performed = WorkoutExercise(
                exercise: exercise,
                exerciseName: exercise.name,
                position: position
            )
            context.insert(performed)

            // Seed three empty sets so the editor is immediately usable.
            for setNumber in 1...3 {
                let entry = SetEntry(setNumber: setNumber)
                context.insert(entry)
                performed.sets.append(entry)
            }

            // Link through the parent: assigning `performed.workout` updates the
            // store but doesn't notify observers of `workout.exercises`, so the
            // open editor would keep showing a stale list.
            workout.exercises.append(performed)
            position += 1
        }
        dismiss()
    }
}
