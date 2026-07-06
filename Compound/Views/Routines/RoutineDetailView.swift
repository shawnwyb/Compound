import SwiftUI
import SwiftData

/// Read-only view of a routine with the entry point to start a workout.
struct RoutineDetailView: View {
    @Bindable var routine: Routine

    @State private var isEditing = false
    @State private var showStartStub = false

    var body: some View {
        List {
            if routine.orderedExercises.isEmpty {
                Text("No exercises yet. Tap Edit to add some.")
                    .foregroundStyle(.secondary)
            } else {
                Section("Exercises") {
                    ForEach(routine.orderedExercises) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.exercise?.name ?? "Deleted exercise")
                                if let group = item.exercise?.group?.name {
                                    Text(group)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(item.targetSets) sets")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(routine.name.isEmpty ? "Untitled" : routine.name)
        .safeAreaInset(edge: .bottom) {
            Button {
                showStartStub = true
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
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineEditorView(routine: routine, isNew: false)
        }
        .alert("Coming in Phase 2", isPresented: $showStartStub) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Running a workout session is implemented in the next phase.")
        }
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .modelContainer(PreviewData.container)
}
