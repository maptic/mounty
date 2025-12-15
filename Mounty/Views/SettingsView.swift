import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: VolumeManager
    @Binding var viewMode: AppViewMode

    // Controls for Overlays
    @State private var showResetConfirmation = false
    @State private var showQuitConfirmation = false
    @State private var showImportDialog = false
    @State private var showExportSuccess = false

    // Input for Import
    @State private var importPath = ""

    let appVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        ?? "1.0"
    let buildNumber =
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HeaderView(
                    title: "Settings",
                    backAction: { withAnimation { viewMode = .list } },
                    trailingAction: {
                        withAnimation { showQuitConfirmation = true }
                    },
                    trailingIcon: ("xmark.circle.fill", .red),
                    trailingHelp: "Quit Mounty"
                )

                Divider()

                // Settings Form
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
                        HStack(spacing: 12) {
                            // Import
                            Button {
                                importPath = ""
                                withAnimation { showImportDialog = true }
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .help("Import volumes from JSON")

                            // Export
                            Button {
                                // Manager handles logic & triggers success alert
                                manager.exportToDownloads()
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .help("Export volumes to Downloads")

                            // Reset
                            Button {
                                withAnimation { showResetConfirmation = true }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .help("Clear all volumes")
                        }
                        .padding(.horizontal, 0)  // No extra padding inside the row
                        .listRowBackground(Color.clear)  // Remove the white group box
                        .listRowInsets(EdgeInsets())  // Span closer to edges (optional)
                    }

                    Section(header: Text("Application Info")) {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image("Logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                                    .cornerRadius(10)

                                Text("Mounty \(appVersion)").font(.headline)
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
                        || showImportDialog || showExportSuccess
                )
                .blur(
                    radius: (showResetConfirmation || showQuitConfirmation
                        || showImportDialog || showExportSuccess) ? 2 : 0
                )
            }

            // --- OVERLAYS ---

            if showResetConfirmation {
                ConfirmationOverlay(
                    title: "Clear All Volumes?",
                    message: "This action cannot be undone.",
                    confirmButtonText: "Clear",
                    isPresented: $showResetConfirmation
                ) {
                    manager.clearAllVolumes()
                    withAnimation { viewMode = .list }
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

            // Success Feedback (Linked to Manager State)
            if manager.showSuccess {
                AlertOverlay(
                    title: "Success",
                    message: manager.successMessage ?? "Operation successful",
                    isPresented: $manager.showSuccess
                )
            }
        }
        // Fallback System Alerts
        .alert(
            "Error",
            isPresented: $manager.showError,
            actions: {},
            message: { Text(manager.lastError ?? "Unknown error") }
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Reusable Overlays

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
                Text(title).font(.headline)
                Text(message).font(.caption).multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                HStack(spacing: 12) {
                    Button("Cancel") { withAnimation { isPresented = false } }
                        .keyboardShortcut(.cancelAction)
                    Button(confirmButtonText) { onConfirm() }
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

struct InputOverlay: View {
    let title: String
    let message: String
    let placeholder: String
    @Binding var inputText: String
    @Binding var isPresented: Bool
    let onConfirm: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture {
                    isFocused = false
                    withAnimation { isPresented = false }
                }

            VStack(spacing: 16) {
                Text(title).font(.headline)
                Text(message).font(.caption).multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                TextField(placeholder, text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)

                HStack(spacing: 12) {
                    Button("Cancel") {
                        isFocused = false
                        withAnimation { isPresented = false }
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Import") {
                        isFocused = false
                        withAnimation { isPresented = false }
                        onConfirm()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20).background(.regularMaterial).cornerRadius(12).shadow(
                radius: 10
            )
            .frame(width: 280).transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}

struct AlertOverlay: View {
    let title: String
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32)).foregroundColor(.green)
                Text(title).font(.headline)
                Text(message).font(.caption).multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("OK") { withAnimation { isPresented = false } }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20).background(.regularMaterial).cornerRadius(12).shadow(
                radius: 10
            )
            .frame(width: 280).transition(.scale.combined(with: .opacity))
        }
    }
}
