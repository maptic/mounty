import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    // Overlay State
    @State private var showResetConfirmation = false
    @State private var showQuitConfirmation = false

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
                        HStack(spacing: 8) {
                            Button {
                                showOpenPanel()
                            } label: {
                                Label("Import", systemImage: "square.and.arrow.up")
                                    .font(.callout)
                                    .frame(maxWidth: .infinity)
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .help("Import volumes from a JSON backup file")

                            Button {
                                showSavePanel()
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.down")
                                    .font(.callout)
                                    .frame(maxWidth: .infinity)
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .help("Export volumes to a JSON backup file")

                            Button {
                                withAnimation { showResetConfirmation = true }
                            } label: {
                                Label("Reset", systemImage: "trash")
                                    .font(.callout)
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.red)
                            }
                            .iconButtonHover(cornerRadius: 6, padding: 6)
                            .disabled(manager.hasActiveVolumeOperations)
                            .help("Clear all volumes")
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
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
                        || manager.showSuccess || manager.showError
                )
                .blur(
                    radius: (showResetConfirmation || showQuitConfirmation
                        || manager.showSuccess || manager.showError) ? 2 : 0
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

    // MARK: - File Panels

    // NSOpenPanel and NSSavePanel are presented app-modally (no parent window)
    // because MenuBarExtra windows cannot host sheets. The popover dismisses
    // naturally when the panel steals focus, but the panel remains fully usable.
    // NSApp.activate ensures the panel appears in the foreground.

    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Select a Mounty backup file to import"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            manager.importVolumes(fromURL: url)
        }
    }

    private func showSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MountyBackup.json"
        panel.message = "Choose where to save your Mounty backup"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            manager.exportToURL(url)
        }
    }
}
