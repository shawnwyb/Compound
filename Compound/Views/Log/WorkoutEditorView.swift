import SwiftUI
import SwiftData

/// The one workout screen, over a persisted `Workout`. It has three modes:
/// - **Live** (`workout.isInProgress`): session timer, Finish / Discard, the
///   rest-timer bar, tappable completion circles, and on-the-fly prefill ghosts.
/// - **New** (`isNew`, finished): a blank manual Log entry with Cancel / Done.
/// - **Finished** (opened from Log): the ⋯ menu (Save as Routine / Delete) and
///   previous-set ghosts.
/// It only ever mutates this `Workout` and its child rows — never a `Routine`.
struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// Root-owned controller; drives the live workout's rest timer and lifecycle
    /// (minimize / end) so the session survives minimize and tab switches.
    @Environment(ActiveWorkout.self) private var activeWorkout

    @Bindable var workout: Workout
    let isNew: Bool

    @Query private var settingsRows: [Settings]
    @Query private var routines: [Routine]

    @State private var sheet: EditorSheet?
    /// Set when the workout is deleted (or a new one cancelled) so the
    /// finalize-on-disappear pass doesn't touch a discarded object.
    @State private var removed = false
    /// Set by Finish so the finished-finalize pass doesn't re-stamp `editedAt`.
    @State private var justFinished = false

    // Live-only state.
    @State private var showDiscardConfirm = false
    /// Prefill ghosts, computed once when the editor appears (history is stable
    /// while it's open, so recomputing per keystroke would be wasteful).
    @State private var ghostMap: [UUID: [PrefilledSet]] = [:]

    private var isLive: Bool { workout.isInProgress }

    private var unit: String {
        settingsRows.first?.units.abbreviation ?? UnitSystem.pounds.abbreviation
    }

    private var settings: Settings { settingsRows.first ?? Settings() }

    private enum EditorSheet: Identifiable {
        case addExercise
        case replace(WorkoutExercise)
        case reorder
        case restTimer

        var id: String {
            switch self {
            case .addExercise: "add"
            case .replace(let exercise): exercise.id.uuidString
            case .reorder: "reorder"
            case .restTimer: "rest"
            }
        }
    }

    var body: some View {
        Form {
            if !isLive {
                Section {
                    // A leading label per row, so the field still says what it is
                    // once the placeholder has been typed over.
                    LabeledContent("Name") {
                        TextField("Workout name", text: $workout.routineName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Start time", selection: startBinding, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End time", selection: endBinding, displayedComponents: [.date, .hourAndMinute])
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                        // Notes run long, so this grows like a text view rather
                        // than scrolling sideways in a one-line field.
                        TextField("How did it go?", text: $workout.notes, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Details").alignedSectionHeader()
                }
            }

            ForEach(workout.orderedExercises) { exercise in
                let ghosts = ghosts(for: exercise)
                Section {
                    ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.id) { index, set in
                        WorkoutSetRow(
                            set: set,
                            unit: unit,
                            ghostWeight: ghostWeight(at: index, in: ghosts),
                            ghostReps: ghostReps(at: index, in: ghosts),
                            isLive: isLive,
                            onToggle: isLive ? { toggleCompleted(set) } : nil
                        )
                    }
                    .onDelete { deleteSets(at: $0, in: exercise) }

                    Button {
                        addSet(to: exercise)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                } header: {
                    exerciseHeader(exercise)
                }
            }

            if !isLive {
                Section {
                    Button {
                        sheet = .addExercise
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .listSectionSpacing(.compact)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) {
            if isLive {
                RestTimerBar(rest: activeWorkout.rest) { sheet = .restTimer }
            }
        }
        .onAppear {
            if ghostMap.isEmpty { ghostMap = computeGhostMap() }
        }
        .onDisappear { finalizeIfNeeded() }
        .sheet(item: $sheet) { active in
            switch active {
            case .addExercise:
                WorkoutExercisePickerView(workout: workout)
            case .replace(let exercise):
                SingleExercisePicker(
                    title: "Replace Exercise",
                    blockedIDs: blockedIDs(excluding: exercise),
                    currentID: exercise.exercise?.id
                ) { chosen in
                    exercise.exercise = chosen
                    exercise.exerciseName = chosen.name
                }
            case .reorder:
                ReorderExercisesView(workout: workout)
            case .restTimer:
                RestTimerSheet(rest: activeWorkout.rest, settings: settings)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $showDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) { discard() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Nothing will be saved to your log.")
        }
        .interactiveDismissDisabled(isNew || isLive)
    }

    // MARK: - Toolbar

    private var navigationTitle: String {
        if isLive { return workout.routineName }
        return isNew ? "New Workout" : "Edit Workout"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isLive {
            ToolbarItem(placement: .topBarLeading) {
                Button { activeWorkout.minimize() } label: {
                    Image(systemName: "chevron.down")
                }
                .accessibilityLabel("Minimize")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button("Discard", role: .destructive) { showDiscardConfirm = true }
            }
            ToolbarItem(placement: .principal) {
                ElapsedTimeText(since: workout.startedAt)
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { finish() }
                    .fontWeight(.semibold)
            }
        } else if isNew {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { cancel() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        saveAsRoutine()
                    } label: {
                        Label("Save as Routine", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        deleteWorkout()
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    /// Live sessions show just the name; finished editing gets the ⋯ menu.
    @ViewBuilder
    private func exerciseHeader(_ exercise: WorkoutExercise) -> some View {
        if isLive {
            Text(exercise.exerciseName).alignedSectionHeader()
        } else {
            HStack {
                Text(exercise.exerciseName)
                Spacer()
                Menu {
                    Button {
                        sheet = .reorder
                    } label: {
                        Label("Reorder", systemImage: "arrow.up.arrow.down")
                    }
                    .disabled(workout.orderedExercises.count < 2)

                    Button {
                        sheet = .replace(exercise)
                    } label: {
                        Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        removeExercise(exercise)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                }
                .textCase(nil)
            }
            .alignedSectionHeader()
        }
    }

    // MARK: - Live session

    /// Finish the live session: fill untouched sets from their ghost, stamp the
    /// finish time and duration, and persist. `justFinished` stops the
    /// disappear-finalize from also treating this as a manual edit.
    private func finish() {
        let now = Date.now
        for exercise in workout.exercises {
            let ghosts = ghosts(for: exercise)
            for (index, set) in exercise.orderedSets.enumerated() where set.reps == 0 && set.weight == 0 {
                guard index < ghosts.count else { continue }
                set.reps = ghosts[index].reps
                set.weight = ghosts[index].weight
            }
        }
        workout.finishedAt = now
        workout.durationSeconds = max(0, Int(now.timeIntervalSince(workout.startedAt)))
        justFinished = true
        try? context.save()
        activeWorkout.end()
    }

    private func discard() {
        // Dismiss now, delete after the cover is fully gone (RootTabView's cover
        // `onDismiss`). Deleting while this view is still dismissing faults
        // SwiftData as it re-renders the workout's set rows.
        removed = true
        activeWorkout.requestDiscard()
    }

    // MARK: - Ghosts

    /// Prefill values per exercise, computed once when the editor appears. A ghost
    /// always means the same thing in both modes — "what you did last time" —
    /// which for a finished session means the sessions before it, never itself.
    private func computeGhostMap() -> [UUID: [PrefilledSet]] {
        // One-time fetch (not a reactive @Query) so per-keystroke autosaves don't
        // refresh a query and re-render the editor while the user is typing.
        let finished = (try? context.fetch(
            FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil })
        )) ?? []
        let priors = isLive
            ? finished
            : finished.filter { $0.id != workout.id && $0.date < workout.date }
        let history = WorkoutHistory.snapshot(priors)
        let routine = routines.first { $0.id == workout.routineID }
        let prefersRoutine = routine?.prefillFromRoutine ?? false
        var map: [UUID: [PrefilledSet]] = [:]
        for exercise in workout.exercises {
            guard let exID = exercise.exercise?.id, map[exID] == nil else { continue }
            map[exID] = PrefillService.lastValues(
                for: exID,
                in: history,
                preferringRoutine: prefersRoutine ? workout.routineID : nil
            )
        }
        return map
    }

    /// Ghost values for an exercise's sets: last time's numbers per set index,
    /// carrying the last known value forward for sets added beyond history.
    private func ghosts(for exercise: WorkoutExercise) -> [(weight: Double, reps: Int)] {
        let prefill: [PrefilledSet] = exercise.exercise.flatMap { ghostMap[$0.id] } ?? []
        var result: [(weight: Double, reps: Int)] = []
        for index in exercise.orderedSets.indices {
            if index < prefill.count {
                result.append((prefill[index].weight, prefill[index].reps))
            } else if let last = result.last {
                result.append(last)
            } else {
                result.append((weight: 0, reps: 0))
            }
        }
        return result
    }

    private func ghostWeight(at index: Int, in ghosts: [(weight: Double, reps: Int)]) -> Double? {
        index < ghosts.count ? ghosts[index].weight : nil
    }

    private func ghostReps(at index: Int, in ghosts: [(weight: Double, reps: Int)]) -> Int? {
        index < ghosts.count ? ghosts[index].reps : nil
    }

    // MARK: - Start / end time bindings

    /// Editing the start keeps the end fixed and recomputes the duration.
    private var startBinding: Binding<Date> {
        Binding(
            get: { workout.startedAt },
            set: { newStart in
                let end = workout.startedAt.addingTimeInterval(Double(workout.durationSeconds))
                workout.startedAt = newStart
                workout.date = newStart
                workout.durationSeconds = max(0, Int(end.timeIntervalSince(newStart)))
            }
        )
    }

    /// Editing the end keeps the start fixed and recomputes the duration.
    private var endBinding: Binding<Date> {
        Binding(
            get: { workout.startedAt.addingTimeInterval(Double(workout.durationSeconds)) },
            set: { newEnd in
                workout.durationSeconds = max(0, Int(newEnd.timeIntervalSince(workout.startedAt)))
            }
        )
    }

    // MARK: - Save / cancel

    private func cancel() {
        removed = true
        if isNew { context.delete(workout) }
        dismiss()
    }

    /// Mark a set done during a live session. Saved right away rather than left to
    /// autosave: this is the one edit that says "real work happened here", and it
    /// has to survive a force-quit for launch recovery to resume the session.
    private func toggleCompleted(_ set: SetEntry) {
        set.completed.toggle()
        try? context.save()
        // Completion is what moves "Set N of M" along on the Lock Screen.
        activeWorkout.refreshActivity()
    }

    /// Commit edits when leaving. Live sessions just persist (Finish / Discard own
    /// the lifecycle); finished editing normalizes the name, derives completion,
    /// and stamps `editedAt`.
    private func finalizeIfNeeded() {
        guard !removed, !justFinished else { return }
        if workout.isInProgress {
            try? context.save()
            return
        }
        if workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            workout.routineName = "Workout"
        }
        // A set with logged reps or weight counts as performed — no manual toggle.
        for exercise in workout.exercises {
            for set in exercise.sets {
                set.completed = set.reps > 0 || set.weight > 0
            }
        }
        if !isNew { workout.editedAt = .now }
        try? context.save()
    }

    private func deleteWorkout() {
        removed = true
        context.delete(workout)
        dismiss()
    }

    /// Create a new routine template from this workout's exercises, using each
    /// exercise's set count as the target. Reps/weight aren't stored on routines.
    private func saveAsRoutine() {
        let name = workout.routineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let routine = Routine(name: name.isEmpty ? "Workout" : name, sortOrder: routines.count)
        context.insert(routine)
        for (index, exercise) in workout.orderedExercises.enumerated() {
            let planned = RoutineExercise(
                exercise: exercise.exercise,
                targetSets: max(1, exercise.sets.count),
                position: index
            )
            context.insert(planned)
            planned.routine = routine
        }
    }

    // MARK: - Sets

    private func addSet(to exercise: WorkoutExercise) {
        // Empty on purpose — the row shows its ghost until the user types.
        let next = (exercise.sets.map(\.setNumber).max() ?? 0) + 1
        let entry = SetEntry(setNumber: next)
        context.insert(entry)
        // Link through the parent so the on-screen set list is notified; assigning
        // `entry.workoutExercise` alone leaves the rendered rows stale.
        exercise.sets.append(entry)
    }

    private func deleteSets(at offsets: IndexSet, in exercise: WorkoutExercise) {
        let ordered = exercise.orderedSets
        for index in offsets {
            context.delete(ordered[index])
        }
        renumberSets(in: exercise)
    }

    private func renumberSets(in exercise: WorkoutExercise) {
        for (index, set) in exercise.orderedSets.enumerated() {
            set.setNumber = index + 1
        }
    }

    // MARK: - Exercises

    private func removeExercise(_ exercise: WorkoutExercise) {
        context.delete(exercise)
        reindexExercises()
    }

    private func reindexExercises() {
        for (index, exercise) in workout.orderedExercises.enumerated() {
            exercise.position = index
        }
    }

    private func blockedIDs(excluding exercise: WorkoutExercise) -> Set<UUID> {
        var ids = Set(workout.exercises.compactMap { $0.exercise?.id })
        if let currentID = exercise.exercise?.id { ids.remove(currentID) }
        return ids
    }
}

/// One editable set row: the shared borderless layout. Live sessions pass a
/// tappable `onToggle`; finished editing leaves it nil so the circle is a plain
/// indicator (filled once the set has data).
private struct WorkoutSetRow: View {
    @Bindable var set: SetEntry
    let unit: String
    /// Ghost placeholders shown in grey until the field is filled in.
    let ghostWeight: Double?
    let ghostReps: Int?
    let isLive: Bool
    var onToggle: (() -> Void)? = nil

    /// Derived here rather than passed in: reading `reps`/`weight` from the
    /// editor's `body` made every keystroke invalidate the whole form — all
    /// sections, every row — instead of just the row being typed into.
    private var completed: Bool {
        isLive ? set.completed : (set.reps > 0 || set.weight > 0)
    }

    var body: some View {
        SetInputRow(
            setNumber: set.setNumber,
            unit: unit,
            ghostWeight: ghostSetNumber(ghostWeight ?? 0),
            ghostReps: ghostSetNumber(Double(ghostReps ?? 0)),
            initialWeight: set.weight != 0 ? formattedSetNumber(set.weight) : "",
            initialReps: set.reps != 0 ? "\(set.reps)" : "",
            note: $set.note,
            completed: completed,
            onToggle: onToggle,
            onWeightChange: { set.weight = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 },
            onRepsChange: { set.reps = Int($0.filter(\.isNumber)) ?? 0 }
        )
    }
}

/// A focused drag-to-reorder screen for the workout's exercises.
private struct ReorderExercisesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var workout: Workout
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                ForEach(workout.orderedExercises) { exercise in
                    Text(exercise.exerciseName)
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func move(_ offsets: IndexSet, to destination: Int) {
        var ordered = workout.orderedExercises
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, exercise) in ordered.enumerated() {
            exercise.position = index
        }
    }
}

#Preview("Finished") {
    NavigationStack {
        WorkoutEditorView(workout: PreviewData.sampleWorkout, isNew: false)
    }
    .environment(ActiveWorkout())
    .modelContainer(PreviewData.container)
}

#Preview("Live") {
    WorkoutEditorView(workout: PreviewData.sampleInProgressWorkout, isNew: false)
        .environment(ActiveWorkout())
        .modelContainer(PreviewData.container)
}
