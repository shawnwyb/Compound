import SwiftUI
import SwiftData

/// Adds a movement the starter library doesn't have. Reached from every place
/// you go looking for an exercise, because "it isn't in the list" is the only
/// moment anyone wants this.
///
/// The created exercise is handed back through `onCreate` so the picker that
/// opened this can select it immediately — otherwise you'd add "Hip Thrust",
/// land back on the list, and have to find and tap it again.
struct NewExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]
    @Query private var library: [Exercise]

    let onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var groupID: UUID?
    @FocusState private var nameFocused: Bool

    private var problem: Exercise.NameProblem? {
        Exercise.nameProblem(name, existing: library.map(\.name))
    }

    /// Nothing typed yet isn't a mistake — it's just the starting state, so the
    /// empty case stays silent and only shows up as a disabled Save.
    private var message: String? {
        switch problem {
        case .duplicate(let existing): "\(existing) is already in your library."
        case .empty, nil: nil
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Exercise name", text: $name)
                        .focused($nameFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(save)
                } header: {
                    Text("Name").alignedSectionHeader()
                } footer: {
                    if let message {
                        Text(message)
                            .foregroundStyle(.red)
                            .alignedSectionFooter()
                    }
                }

                Section {
                    Picker("Muscle Group", selection: $groupID) {
                        ForEach(groups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                        // Groups can be deleted, and an exercise without one is
                        // already a state the app shows as "Uncategorized" —
                        // so it's offered here rather than being forced.
                        Text("Uncategorized").tag(UUID?.none)
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Muscle Group").alignedSectionHeader()
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(16)
            .keyboardDoneButton()
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(problem != nil)
                }
            }
            .onAppear {
                if groupID == nil { groupID = groups.first?.id }
                nameFocused = true
            }
        }
    }

    private func save() {
        guard problem == nil else { return }
        let group = groups.first { $0.id == groupID }
        let exercise = Exercise(
            name: Exercise.normalizedName(name),
            group: group,
            isCustom: true
        )
        context.insert(exercise)
        // Linked through the parent: assigning `exercise.group` updates the
        // store but doesn't tell anything observing `group.exercises`, so the
        // picker underneath would come back without the new row.
        group?.exercises.append(exercise)
        onCreate(exercise)
        dismiss()
    }
}

#Preview {
    NewExerciseView { _ in }
        .modelContainer(PreviewData.container)
}
