import SwiftUI
import SwiftData

/// The Routines tab: a flat, reorderable list of workout templates.
struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]

    @State private var editingRoutine: Routine?
    @State private var editingIsNew = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No Routines", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("A routine is a template you start workouts from.")
                    } actions: {
                        Button("New Routine") { addRoutine() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineRow(routine: routine)
                            }
                        }
                        .onDelete(perform: delete)
                        .onMove(perform: move)
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .listSectionSpacing(16)
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !routines.isEmpty { EditButton() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addRoutine() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Routine")
                }
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine, isNew: editingIsNew)
            }
        }
    }

    private func addRoutine() {
        let routine = Routine(name: "", sortOrder: routines.count)
        context.insert(routine)
        editingIsNew = true
        editingRoutine = routine
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            context.delete(routines[index])
        }
        reindex()
    }

    private func move(_ offsets: IndexSet, to destination: Int) {
        var ordered = routines
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, routine) in ordered.enumerated() {
            routine.sortOrder = index
        }
    }

    private func reindex() {
        for (index, routine) in routines.enumerated() where routine.sortOrder != index {
            routine.sortOrder = index
        }
    }
}

private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name.isEmpty ? "Untitled" : routine.name)
                .font(.headline)
            Text(exerciseSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var exerciseSummary: String {
        let count = routine.exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }
}

#Preview {
    RoutinesView()
        .modelContainer(PreviewData.container)
}
