import SwiftUI
import SwiftData

/// Read-only view of a routine with the entry point to start a workout.
struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine

    @State private var isEditing = false
    @State private var session: WorkoutSession?

    var body: some View {
        List {
            if routine.orderedExercises.isEmpty {
                Text("No exercises yet. Tap Edit to add some.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
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
                } header: {
                    Text("Exercises").alignedSectionHeader()
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .navigationTitle(routine.name.isEmpty ? "Untitled" : routine.name)
        .safeAreaInset(edge: .bottom) {
            Button {
                session = WorkoutHistory.makeSession(for: routine, context: context)
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
        .fullScreenCover(item: $session) { session in
            WorkoutSessionView(session: session)
        }
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routine: PreviewData.sampleRoutine)
    }
    .modelContainer(PreviewData.container)
}
