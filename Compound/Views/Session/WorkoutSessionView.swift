import SwiftUI
import SwiftData

/// The live workout screen: session timer, per-set logging, and a manually
/// opened rest timer.
struct WorkoutSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsRows: [Settings]

    @Bindable var session: WorkoutSession
    @State private var showDiscardConfirm = false
    @State private var showTimer = false

    private var settings: Settings { settingsRows.first ?? Settings() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.exercises) { exercise in
                    Section {
                        ForEach(exercise.sets) { set in
                            SetRow(set: set, unit: settings.units.abbreviation) { session.toggle(set) }
                        }
                        .onDelete { exercise.deleteSets(at: $0) }

                        Button {
                            exercise.addSet()
                        } label: {
                            Label("Add Set", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        Text(exercise.name).alignedSectionHeader()
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .listSectionSpacing(.compact)
            .navigationTitle(session.routineName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) { showDiscardConfirm = true }
                }
                ToolbarItem(placement: .principal) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(TimeFormat.clock(session.elapsedSeconds(at: context.date)))
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { finish() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                RestTimerButton(rest: session.rest, settings: settings) { showTimer = true }
            }
            .sheet(isPresented: $showTimer) {
                RestTimerSheet(rest: session.rest, settings: settings)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .confirmationDialog(
                "Discard this workout?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Nothing will be saved to your log.")
            }
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        WorkoutHistory.persist(session, context: context)
        dismiss()
    }
}

/// One logged set: number, weight, reps, and a completion toggle.
private struct SetRow: View {
    @Bindable var set: SessionSet
    let unit: String
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(set.setNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            numberField(value: $set.weight, unit: unit, width: 66)
            intField(value: $set.reps, unit: "reps", width: 58)

            Spacer()

            Button(action: onToggle) {
                Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func numberField(value: Binding<Double>, unit: String, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func intField(value: Binding<Int>, unit: String, width: CGFloat) -> some View {
        HStack(spacing: 4) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Always-visible bottom bar that opens the rest timer; shows the live
/// countdown when a rest is running, and auto-stops it at zero.
private struct RestTimerButton: View {
    @Bindable var rest: RestTimer
    let settings: Settings
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = rest.remaining(at: context.date)
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                    if rest.isActive {
                        Text(TimeFormat.clock(remaining))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    } else {
                        Text("Rest Timer")
                    }
                    Spacer()
                    Image(systemName: "chevron.up")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .contentShape(Rectangle())
                .onChange(of: remaining) { _, newValue in
                    if rest.isActive && newValue == 0 {
                        RestCompletionAlert.play(
                            sound: settings.restSoundEnabled,
                            vibration: settings.restVibrationEnabled
                        )
                        rest.stop()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .background(.bar)
    }
}

/// The draggable rest-timer sheet: live countdown, running controls, and
/// tappable presets the user can add to or delete.
private struct RestTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var rest: RestTimer
    @Bindable var settings: Settings

    @State private var showAddPreset = false

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    countdown

                    if rest.isActive {
                        HStack(spacing: 12) {
                            Button("−15") { rest.adjust(by: -15) }
                                .buttonStyle(.bordered)
                            Button("+15") { rest.adjust(by: 15) }
                                .buttonStyle(.bordered)
                            Button("Skip") { rest.stop() }
                                .buttonStyle(.borderedProminent)
                        }
                        .font(.headline)
                    } else {
                        Button {
                            rest.start(seconds: settings.defaultRestSeconds)
                        } label: {
                            Text("Start \(TimeFormat.clock(settings.defaultRestSeconds))")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.headline)
                    }

                    presets
                }
                .padding()
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddPreset) {
                AddPresetSheet(settings: settings)
            }
        }
    }

    private var countdown: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = rest.isActive ? rest.remaining(at: context.date) : 0
            Text(TimeFormat.clock(remaining))
                .font(.system(size: 68, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(rest.isActive ? .primary : .secondary)
        }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(settings.restPresets.sorted(), id: \.self) { seconds in
                    Button {
                        rest.start(seconds: seconds)
                    } label: {
                        Text(TimeFormat.clock(seconds))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .contextMenu {
                        Button("Delete", role: .destructive) { deletePreset(seconds) }
                    }
                }

                Button {
                    showAddPreset = true
                } label: {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
            Text("Tap a preset to start. Long-press to delete.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func deletePreset(_ seconds: Int) {
        settings.restPresets = settings.restPresets.filter { $0 != seconds }
    }
}

/// Compact sheet to create a new rest preset.
private struct AddPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings: Settings
    @State private var seconds = 60

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: $seconds, in: 5...600, step: 5) {
                    Text("Duration: \(TimeFormat.clock(seconds))")
                }
            }
            .navigationTitle("New Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addPreset() }
                }
            }
        }
        .presentationDetents([.height(180)])
    }

    private func addPreset() {
        if !settings.restPresets.contains(seconds) {
            settings.restPresets = (settings.restPresets + [seconds]).sorted()
        }
        dismiss()
    }
}

#Preview {
    WorkoutSessionView(
        session: WorkoutSession(
            routineID: nil,
            routineName: "Push Day",
            exercises: [
                SessionExercise(exercise: nil, name: "Bench Press", sets: [
                    SessionSet(setNumber: 1, reps: 8, weight: 135),
                    SessionSet(setNumber: 2, reps: 8, weight: 135),
                    SessionSet(setNumber: 3, reps: 6, weight: 145),
                ]),
                SessionExercise(exercise: nil, name: "Incline Dumbbell Press", sets: [
                    SessionSet(setNumber: 1, reps: 10, weight: 50),
                ]),
            ]
        )
    )
    .modelContainer(PreviewData.container)
}
