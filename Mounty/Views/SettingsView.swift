import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    // Alert State
    @State private var showResetConfirmation = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ZStack {
            // MARK: - Main Content
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
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    Text("Settings").font(.headline)
                    Spacer()
                    Text("Back").hidden()
                }
                .padding(12)
                .background(.regularMaterial)
                
                Divider()
                
                // Settings Form
                Form {
                    Section {
                        Toggle("Launch at Login", isOn: Binding(
                            get: { manager.launchAtLogin },
                            set: { manager.toggleLaunchAtLogin($0) }
                        ))
                        .toggleStyle(.switch)
                        
                        Picker("Terminal App", selection: Binding(
                            get: { manager.preferredTerminal },
                            set: { manager.setPreferredTerminal($0) }
                        )) {
                            ForEach(manager.availableTerminals, id: \.id) { (name, bundleID) in
                                Text(name).tag(bundleID)
                            }
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text("General")
                    }
                    
                    Section {
                        Button("Reset App Data") {
                            // Trigger the overlay
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showResetConfirmation = true
                            }
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("Data")
                    }
                    
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "externaldrive.connected.to.line.below")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary)
                                Text("Mounty \(appVersion)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Build \(buildNumber)")
                                    .font(.caption2)
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
                .disabled(showResetConfirmation) // Disable interaction behind overlay
                .blur(radius: showResetConfirmation ? 2 : 0) // Blur background slightly
            }
            
            // MARK: - Alert Overlay
            if showResetConfirmation {
                Color.black.opacity(0.2) // Dimmer
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showResetConfirmation = false }
                    }
                
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Reset App Data?")
                            .font(.headline)
                        Text("This will remove all configured filers.\nThis action cannot be undone.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            withAnimation { showResetConfirmation = false }
                        }
                        .keyboardShortcut(.cancelAction)
                        
                        Button("Reset") {
                            manager.removeAllFilers()
                            withAnimation {
                                showResetConfirmation = false
                                viewMode = .list
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
                .frame(width: 280) // Fixed width for nice look
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
