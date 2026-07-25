import SwiftUI
import SwiftData

/// Reusable single-select exercise browser (grouped by muscle) for swapping one
/// exercise slot for another. `blockedIDs` are hidden to avoid duplicates;
/// `currentID` gets a checkmark. Selecting one fires `onSelect` and dismisses.
struct SingleExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]

    let title: String
    let blockedIDs: Set<UUID>
    let currentID: UUID?
    let onSelect: (Exercise) -> Void

    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    let exercises = available(in: group)
                    if !exercises.isEmpty {
                        Section {
                            ForEach(exercises) { exercise in
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func available(in group: MuscleGroup) -> [Exercise] {
        group.exercises
            .filter { !blockedIDs.contains($0.id) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }
}
