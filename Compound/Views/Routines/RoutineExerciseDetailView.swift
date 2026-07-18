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
                    Stepper("Sets", value: $routineExercise.targetSets, in: 1...20)
                        .labelsHidden()
                }
            } header: {
                Text("Target Sets").alignedSectionHeader()
            }

            Section {
                Button("Replace Exercise") {
                    showReplace = true
                }
                Button("Remove from Routine", role: .destructive) {
                    removeFromRoutine()
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(routineExercise.exercise?.name ?? "Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showReplace) {
            SingleExercisePicker(
                title: "Replace Exercise",
                blockedIDs: blockedIDs,
                currentID: routineExercise.exercise?.id
            ) { chosen in
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

    /// Exercises already in the routine other than this one — hidden in the
    /// replace picker to avoid creating a duplicate.
    private var blockedIDs: Set<UUID> {
        var ids = Set(routine.exercises.compactMap { $0.exercise?.id })
        if let currentID = routineExercise.exercise?.id { ids.remove(currentID) }
        return ids
    }
}
