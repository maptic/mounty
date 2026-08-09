import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    // Overlay State
    @State private var showResetConfirmation = false
    @State private var showQuitConfirmation = false
    @State private var showImportDialog = false

    // Import Logic
    @State private var importPath = ""

    let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? "1.0"
    let buildNumber =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            // Main Settings Content
            VStack(alignment: .leading, spacing: 0) {
                HeaderView(
                    title: "Settings",
                    backAction: { viewMode = .list },
                    trailingAction: { showQuitConfirmation = true },
                    trailingIcon: ("xmark.circle.fill", .red),
                    trailingHelp: "Quit Mounty"
                )

                Divider()

                Form {
                    Section(header: Text("General")) {
                        Toggle("Launch at Login", isOn: $manager.launchAtLogin)
                            .onChange(of: manager.launchAtLogin) { _, v in
                                manager.toggleLaunchAtLogin(v)
                            }

                        Picker(
                            "Terminal App",
                            selection: $manager.preferredTerminal
                        ) {
                            ForEach(manager.availableTerminals, id: \.id) {
                                Text($0.name).tag($0.id)
                            }
                        }
                        .onChange(of: manager.preferredTerminal) { _, v in
                            manager.setPreferredTerminal(v)
                        }
                    }

                    Section(header: Text("Volumes")) {
                        HStack {
                            Spacer()
                            Button {
                                importPath = ""
                                withAnimation { showImportDialog = true }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .help("Import volumes from JSON")

                            Spacer()

                            Button {
                                manager.exportToDownloads()
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14))
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .help("Export volumes to Downloads")

                            Spacer()

                            Button {
                                withAnimation { showResetConfirmation = true }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .help("Clear all volumes")

                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }

                    Section(header: Text("Application Info")) {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(
                                    nsImage: NSImage(
                                        named: NSImage.applicationIconName
                                    ) ?? NSImage()
                                )
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)

                                Text("Mounty").font(.headline)
                                Text("Version \(appVersion) (\(buildNumber))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .disabled(
                    showResetConfirmation || showQuitConfirmation
                        || showImportDialog || manager.showSuccess
                        || manager.showError
                )
                .blur(
                    radius: (showResetConfirmation || showQuitConfirmation
                        || showImportDialog || manager.showSuccess
                        || manager.showError) ? 2 : 0
                )
            }

            // Overlays Layer

            if showResetConfirmation {
                ConfirmationOverlay(
                    title: "Clear All Volumes?",
                    message: "This action cannot be undone.",
                    confirmButtonText: "Clear",
                    isPresented: $showResetConfirmation
                ) {
                    manager.clearAllVolumes()
                    viewMode = .list
                }
            }

            if showQuitConfirmation {
                ConfirmationOverlay(
                    title: "Quit Mounty?",
                    message: "Are you sure you want to quit?",
                    confirmButtonText: "Quit",
                    isPresented: $showQuitConfirmation
                ) {
                    NSApplication.shared.terminate(nil)
                }
            }

            if showImportDialog {
                InputOverlay(
                    title: "Import Volumes",
                    message: "Enter full path to backup file",
                    placeholder: "~/Downloads/MountyBackup.json",
                    inputText: $importPath,
                    isPresented: $showImportDialog
                ) {
                    manager.importVolumes(fromPath: importPath)
                }
            }

            // ViewModel Feedback Overlays
            if manager.showSuccess {
                AlertOverlay(
                    title: "Success",
                    message: manager.successMessage ?? "Operation successful",
                    isPresented: $manager.showSuccess,
                    isError: false
                )
            }

            if manager.showError {
                AlertOverlay(
                    title: "Error",
                    message: manager.lastError ?? "Unknown error",
                    isPresented: $manager.showError,
                    isError: true
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
