import SwiftUI

/// Always-visible bottom bar that opens the rest timer; shows the live
/// countdown when a rest is running. Display only — `RestTimer` stops itself at
/// zero and plays the completion cue.
struct RestTimerBar: View {
    @Bindable var rest: RestTimer
    let onTap: () -> Void

    var body: some View {
        // Only the countdown ticks. This bar is on screen for the whole session,
        // so wrapping all of it in the `TimelineView` rebuilt the buttons and
        // layout once a second — and kept doing it between rests, when the label
        // is a fixed string.
        HStack(spacing: 10) {
            if rest.isActive {
                // Inline stop — ends the rest without opening the sheet.
                Button { rest.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                RestCountdownText(rest: rest)
                    .fontWeight(.semibold)
            } else {
                Image(systemName: "timer")
                Text("Rest Timer")
            }
            Spacer()
            Image(systemName: "chevron.up")
                .foregroundStyle(.secondary)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .background(.bar)
    }
}

/// The draggable rest-timer sheet: live countdown, running controls, and
/// tappable presets the user can add to or delete.
struct RestTimerSheet: View {
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

    @ViewBuilder
    private var countdown: some View {
        // Idle shows a static zero rather than a `TimelineView` ticking over an
        // unchanging string.
        if rest.isActive {
            RestCountdownText(rest: rest)
                .font(.system(size: 68, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        } else {
            Text(TimeFormat.clock(0))
                .font(.system(size: 68, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
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
