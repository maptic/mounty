import SwiftUI

struct FilerRow: View {
    let filer: Filer
    @ObservedObject var manager: FilerManager
    
    var isMounted: Bool { manager.mountPaths[filer.id] != nil }
    var isBusy: Bool { manager.busyFilers.contains(filer.id) }
    var currentPath: String { manager.mountPaths[filer.id] ?? "Disconnected" }
    
    var body: some View {
        HStack(spacing: 12) {
            // Server Icon
            Image(systemName: "server.rack")
                .font(.system(size: 24))
                .foregroundColor(isMounted ? .accentColor : .secondary.opacity(0.5))
            
            // Info Text
            VStack(alignment: .leading, spacing: 2) {
                Text(filer.name)
                    .font(.system(size: 13, weight: .medium))
                
                Text(isMounted ? currentPath : filer.serverAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // --- Action Buttons ---
            HStack(spacing: 8) {
                
                // 1. Automount Toggle (The Bolt)
                Button {
                    manager.toggleAutomount(filer.id)
                } label: {
                    Image(systemName: filer.isAutomountEnabled ? "bolt.fill" : "bolt")
                        .font(.system(size: 14))
                        .foregroundColor(filer.isAutomountEnabled ? .orange : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help(filer.isAutomountEnabled ? "Disable Automount" : "Enable Automount")
                
                // 2. Mounted Actions (Terminal / Copy)
                if isMounted {
                    Button { manager.openTerminal(for: filer) } label: {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Open Terminal")

                    Button { manager.copyPath(for: filer) } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Copy Path")
                }
                
                // 3. Connect / Disconnect Main Action
                Button {
                    if isMounted { manager.unmount(filer) } else { manager.mount(filer) }
                } label: {
                    if isBusy {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else {
                        Image(systemName: isMounted ? "cable.connector.slash" : "cable.connector.horizontal")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isMounted ? .red : .green)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .help(isMounted ? "Disconnect" : "Connect")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contextMenu {
            Button(role: .destructive) { manager.removeFiler(filer.id) } label: {
                Text("Remove Filer")
            }
        }
    }
}
