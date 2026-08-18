import SwiftUI
import SwiftData

/// Reusable single-select exercise browser (grouped by muscle) for swapping one
/// exercise slot for another. `blockedIDs` are hidden to avoid duplicates;
/// `currentID` gets a checkmark. Selecting one fires `onSelect` and dismisses.
struct SingleExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]
    @Query private var library: [Exercise]

    let title: String
    let blockedIDs: Set<UUID>
    let currentID: UUID?
    let onSelect: (Exercise) -> Void

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
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if exercise.id == currentID {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
                // Single-select: creating one *is* choosing it, so this picker
                // reports it and closes rather than dropping you back on a list
                // to find the row you just made.
                NewExerciseView { created in
                    onSelect(created)
                    dismiss()
                }
            }
            .deleteCustomExerciseDialog(pending: $pendingDelete)
        }
    }

    private func available(in group: MuscleGroup) -> [Exercise] {
        library
            .filter { $0.group?.id == group.id }
            .filter { !blockedIDs.contains($0.id) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }
}
