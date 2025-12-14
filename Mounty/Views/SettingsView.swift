import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
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
                        ForEach(manager.terminalOptions, id: \.1) { (name, bundleID) in
                            Text(name).tag(bundleID)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("General")
                }
                
                Section {
                    Button("Reset App Data") {
                        manager.removeAllFilers()
                        withAnimation { viewMode = .list }
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
        }
    }
}
