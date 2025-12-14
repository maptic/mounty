import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    // Retrieve App Bundle Info
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Back Button
            HStack {
                Button { viewMode = .list } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Text("Settings").font(.headline).padding(.leading, 8)
                Spacer()
            }
            .padding()
            .background(.regularMaterial)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // General Section
                    GroupBox(label: Label("General", systemImage: "gear")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Start at Login", isOn: Binding(
                                get: { manager.launchAtLogin },
                                set: { manager.toggleLaunchAtLogin($0) }
                            ))
                            .toggleStyle(.switch)
                            
                            Text("Automatically launch Mounty when you log in to your Mac.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(4)
                    }
                    
                    // Danger Zone
                    GroupBox(label: Label("Reset", systemImage: "trash").foregroundColor(.red)) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Remove all configured filers and reset app state.")
                                .font(.caption).foregroundColor(.secondary)
                            
                            Button("Reset App Data", role: .destructive) {
                                manager.removeAllFilers()
                                viewMode = .list
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(.red)
                        }
                        .padding(4)
                    }
                    
                    // About Section
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "externaldrive.connected.to.line.below")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Mounty")
                            .font(.headline)
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Created with SwiftUI")
                            .font(.caption2)
                            // FIX: Use NSColor.tertiaryLabelColor
                            .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
                .padding(20)
            }
        }
    }
}
