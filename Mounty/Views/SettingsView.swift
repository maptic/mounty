import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    @State private var showResetConfirmation = false
    @State private var showQuitConfirmation = false

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
                // Header - With Centered Title and Quit Button
                HStack {
                    // Leading Item: Back button without text for balance
                    Button {
                        withAnimation { viewMode = .list }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundColor(.accentColor)
                    .frame(width: 24, alignment: .leading)

                    Spacer()

                    // Center Item
                    Text("Settings").font(.headline)

                    Spacer()

                    // Trailing Item: Quit button
                    Button {
                        withAnimation { showQuitConfirmation = true }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Quit Mounty")
                    .frame(width: 24, alignment: .trailing)
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

                    // About Section with App Icon
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image("Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(6)

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
                .scrollDisabled(true)
                .disabled(showResetConfirmation || showQuitConfirmation)
                .blur(
                    radius: (showResetConfirmation || showQuitConfirmation)
                        ? 2 : 0
                )
            }

            // Custom Reset Alert Overlay
            if showResetConfirmation {
                ConfirmationOverlay(
                    title: "Clear All Volumes?",
                    message:
                        "This will remove all configured volumes.\nThis action cannot be undone.",
                    confirmButtonText: "Clear",
                    isPresented: $showResetConfirmation
                ) {
                    manager.clearAllVolumes()
                    withAnimation { viewMode = .list }
                }
            }

            // Custom Quit Alert Overlay
            if showQuitConfirmation {
                ConfirmationOverlay(
                    title: "Quit Mounty?",
                    message: "Are you sure you want to quit the application?",
                    confirmButtonText: "Quit",
                    isPresented: $showQuitConfirmation
                ) {
                    NSApplication.shared.terminate(nil)
                }
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

// Reusable confirmation view to avoid duplicate code
struct ConfirmationOverlay: View {
    let title: String
    let message: String
    let confirmButtonText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text(title).font(.headline)
                    Text(message)
                        .font(.caption).multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 12) {
                    Button("Cancel") { withAnimation { isPresented = false } }
                        .keyboardShortcut(.cancelAction)
                    Button(confirmButtonText) {
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent).tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20).background(.regularMaterial).cornerRadius(12).shadow(
                radius: 10
            )
            .frame(width: 280).transition(.scale.combined(with: .opacity))
        }
    }
}

// Helper for FileExporter
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
