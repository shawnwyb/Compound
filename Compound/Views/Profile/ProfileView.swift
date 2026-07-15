import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Profile tab: units, rest timer, theme, export, and about.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsRows: [Settings]

    @State private var showAddPreset = false
    @State private var exportDocument: ExportDocument?
    @State private var showExporter = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let settings = settingsRows.first {
                    profileForm(settings)
                } else {
                    ProgressView()
                        .onAppear { _ = Settings.current(in: context) }
                }
            }
            .navigationTitle("Profile")
        }
    }

    @ViewBuilder
    private func profileForm(_ settings: Settings) -> some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("Units", selection: unitsBinding(for: settings)) {
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }

                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemePreference.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("Changing units converts every saved weight to the new system.")
            }

            Section("Rest Timer") {
                Stepper(value: $settings.defaultRestSeconds, in: 5...600, step: 5) {
                    Text("Default rest: \(TimeFormat.clock(settings.defaultRestSeconds))")
                }
                Toggle("Sound", isOn: $settings.restSoundEnabled)
                Toggle("Vibration", isOn: $settings.restVibrationEnabled)
            }

            Section {
                ForEach(settings.restPresets.sorted(), id: \.self) { seconds in
                    Text(TimeFormat.clock(seconds))
                }
                .onDelete { deletePresets(at: $0, settings: settings) }

                Button {
                    showAddPreset = true
                } label: {
                    Label("Add Preset", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Rest Presets")
            } footer: {
                Text("These appear in the workout rest timer. Swipe to delete.")
            }

            Section("Data") {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
            }

            Section("About") {
                LabeledContent("App", value: "Compound")
                LabeledContent("Version", value: appVersion)
            }
        }
        .sheet(isPresented: $showAddPreset) {
            AddRestPresetSheet(settings: settings)
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: DataExport.suggestedFileName()
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
            exportDocument = nil
        }
        .alert("Export Failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    /// Converts all stored weights when the unit system changes.
    private func unitsBinding(for settings: Settings) -> Binding<UnitSystem> {
        Binding(
            get: { settings.units },
            set: { newValue in
                let old = settings.units
                guard old != newValue else { return }
                convertAllWeights(from: old, to: newValue)
                settings.units = newValue
                try? context.save()
            }
        )
    }

    private func convertAllWeights(from: UnitSystem, to: UnitSystem) {
        let sets = (try? context.fetch(FetchDescriptor<SetEntry>())) ?? []
        for set in sets {
            set.weight = WeightConversion.convert(set.weight, from: from, to: to)
        }
        let dailyEntries = (try? context.fetch(FetchDescriptor<DailyEntry>())) ?? []
        for entry in dailyEntries where entry.bodyWeight != nil {
            entry.bodyWeight = WeightConversion.convert(entry.bodyWeight!, from: from, to: to)
        }
    }

    private func deletePresets(at offsets: IndexSet, settings: Settings) {
        let sorted = settings.restPresets.sorted()
        var next = settings.restPresets
        for index in offsets {
            let value = sorted[index]
            next.removeAll { $0 == value }
        }
        settings.restPresets = next.sorted()
    }

    private func exportBackup() {
        do {
            let data = try DataExport.jsonData(from: context)
            exportDocument = ExportDocument(data: data)
            showExporter = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// File-exporter wrapper for the JSON backup.
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Sheet to add a rest-timer preset from Profile.
private struct AddRestPresetSheet: View {
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
                    Button("Add") {
                        if !settings.restPresets.contains(seconds) {
                            settings.restPresets = (settings.restPresets + [seconds]).sorted()
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}

#Preview {
    ProfileView()
        .modelContainer(PreviewData.container)
}
