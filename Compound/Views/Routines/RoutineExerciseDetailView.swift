import SwiftUI
import SwiftData

/// Compact summary of a planned exercise for the routine list: name, muscle
/// group, and its target set count. Tapping the row opens the detail editor.
struct RoutineExerciseSummaryRow: View {
    let item: RoutineExercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise?.name ?? "Deleted exercise")
                if let group = item.exercise?.group?.name {
                    Text(group)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.targetSets == 1 ? "1 set" : "\(item.targetSets) sets")
                .foregroundStyle(.secondary)
        }
    }
}

/// Per-exercise editor within a routine: adjust the target set count, swap the
/// exercise for another, or remove it from the routine.
struct RoutineExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var routineExercise: RoutineExercise
    let routine: Routine

    @State private var setsText = ""
    @FocusState private var setsFocused: Bool
    @State private var showReplace = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text("Sets")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("", text: $setsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .focused($setsFocused)
                        .onChange(of: setsText) { _, newValue in
                            let digits = String(newValue.filter(\.isNumber).prefix(2))
                            if digits != newValue { setsText = digits }
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { setsFocused = false }
                            }
                        }
                    Stepper("Sets", value: $routineExercise.targetSets, in: 1...20)
                        .labelsHidden()
                }
            } header: {
                Text("Target Sets").alignedSectionHeader()
            }

            Section {
                Button {
                    showReplace = true
                } label: {
                    Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                }
                Button(role: .destructive) {
                    removeFromRoutine()
                } label: {
                    Label("Remove from Routine", systemImage: "trash")
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationTitle(routineExercise.exercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReplace) {
            ReplaceExercisePicker(routine: routine, current: routineExercise) { chosen in
                routineExercise.exercise = chosen
            }
        }
        .onAppear {
            if setsText.isEmpty { setsText = "\(routineExercise.targetSets)" }
        }
        .onChange(of: routineExercise.targetSets) { _, newValue in
            if !setsFocused { setsText = "\(newValue)" }
        }
        .onChange(of: setsFocused) { _, focused in
            if !focused { commitSets() }
        }
    }

    private func commitSets() {
        let clamped = min(max(Int(setsText) ?? routineExercise.targetSets, 1), 20)
        routineExercise.targetSets = clamped
        setsText = "\(clamped)"
    }

    private func removeFromRoutine() {
        context.delete(routineExercise)
        for (index, item) in routine.orderedExercises.enumerated() {
            item.position = index
        }
        dismiss()
    }
}

/// Single-select exercise browser used to swap one routine slot for another.
/// Exercises already in the routine (other than the current one) are hidden to
/// avoid creating a duplicate.
private struct ReplaceExercisePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MuscleGroup.sortOrder) private var groups: [MuscleGroup]

    let routine: Routine
    let current: RoutineExercise
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
                                        if exercise.id == current.exercise?.id {
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
            .listSectionSpacing(.compact)
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Replace Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var blockedIDs: Set<UUID> {
        var ids = Set(routine.exercises.compactMap { $0.exercise?.id })
        if let currentID = current.exercise?.id { ids.remove(currentID) }
        return ids
    }

    private func available(in group: MuscleGroup) -> [Exercise] {
        group.exercises
            .filter { !blockedIDs.contains($0.id) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name < $1.name }
    }
}
