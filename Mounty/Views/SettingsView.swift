import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode
    @State private var showResetConfirmation = false

    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var importError: String?
    @State private var showErrorAlert = false

    let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? "1.0"
    let buildNumber =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Button {
                        withAnimation { viewMode = .list }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(.plain).foregroundColor(.accentColor)
                    Spacer()
                    Text("Settings").font(.headline)
                    Spacer()
                    Text("Back").hidden()
                }
                .padding(12).background(.regularMaterial)

                Divider()

                // Settings Form
                Form {
                    Section(header: Text("General")) {
                        Toggle("Launch at Login", isOn: $manager.launchAtLogin)
                            .onChange(of: manager.launchAtLogin) {
                                _,
                                newValue in
                                manager.toggleLaunchAtLogin(newValue)
                            }

                        Picker(
                            "Terminal App",
                            selection: $manager.preferredTerminal
                        ) {
                            ForEach(manager.availableTerminals, id: \.id) {
                                Text($0.name).tag($0.id)
                            }
                        }
                        .onChange(of: manager.preferredTerminal) {
                            _,
                            newValue in
                            manager.setPreferredTerminal(newValue)
                        }
                    }

                    Section(header: Text("Data Management")) {
                        HStack {
                            Spacer()
                            Button {
                                showFileImporter = true
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                            }
                            .help("Import from Backup")

                            Button {
                                showFileExporter = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .help("Export to Backup")

                            Button {
                                withAnimation { showResetConfirmation = true }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("Clear All Volumes")
                            .tint(.red)
                            Spacer()
                        }
                        .buttonStyle(.bordered).controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }

                    Section(header: Text("Application")) {
                        HStack {
                            Spacer()
                            Button("Quit Mounty") {
                                NSApplication.shared.terminate(nil)
                            }
                            Spacer()
                        }
                    }

                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(
                                    systemName:
                                        "externaldrive.connected.to.line.below"
                                )
                                .font(.system(size: 24)).foregroundColor(
                                    .secondary
                                )
                                Text("Mounty \(appVersion)").font(.caption)
                                    .fontWeight(.medium)
                                Text("Build \(buildNumber)").font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8).listRowBackground(Color.clear)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)  // Prevent scrolling within the form
                .disabled(showResetConfirmation)
                .blur(radius: showResetConfirmation ? 2 : 0)
            }

            // Custom Alert Overlay
            if showResetConfirmation {
                Color.black.opacity(0.2).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showResetConfirmation = false }
                    }

                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Clear All Volumes?").font(.headline)
                        Text(
                            "This will remove all configured volumes.\nThis action cannot be undone."
                        )
                        .font(.caption).multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            withAnimation { showResetConfirmation = false }
                        }
                        .keyboardShortcut(.cancelAction)
                        Button("Clear") {
                            manager.clearAllVolumes()
                            withAnimation {
                                showResetConfirmation = false
                                viewMode = .list
                            }
                        }
                        .buttonStyle(.borderedProminent).tint(.red)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20).background(.regularMaterial).cornerRadius(12)
                .shadow(radius: 10)
                .frame(width: 280).transition(.scale.combined(with: .opacity))
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json]
        ) { handleImport(result: $0) }
        .fileExporter(
            isPresented: $showFileExporter,
            document: VolumeBackup(volumes: manager.volumes),
            contentType: .json,
            defaultFilename: "MountyBackup.json"
        ) { _ in }
        .alert(
            "Import Error",
            isPresented: $showErrorAlert,
            actions: {},
            message: { Text(importError ?? "Unknown error") }
        )
        // FIX: Forces the view to take up its ideal height, preventing truncation.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                try manager.importVolumes(from: data)
            } catch {
                importError =
                    "Failed to decode backup file. It may be corrupt. (\(error.localizedDescription))"
                showErrorAlert = true
            }
        case .failure(let error):
            importError = "Failed to select file: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

// Helper for FileExporter (unchanged)
struct VolumeBackup: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var volumes: [Volume]

    init(volumes: [Volume]) { self.volumes = volumes }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.volumes = try JSONDecoder().decode([Volume].self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(volumes)
        return FileWrapper(regularFileWithContents: data)
    }
}
