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
                
                // 1. Automount Toggle (Bolt)
                Button {
                    manager.toggleAutomount(filer.id)
                } label: {
                    Image(systemName: filer.isAutomountEnabled ? "bolt.fill" : "bolt")
                        .font(.system(size: 14))
                        .foregroundColor(filer.isAutomountEnabled ? .orange : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .help(filer.isAutomountEnabled ? "Disable Automount" : "Enable Automount")
                
                // 2. Mounted Actions
                if isMounted {
                    Button { manager.openInTerminal(filer) } label: {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Open in Terminal")

                    Button { manager.openInFinder(filer) } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Show in Finder")
                }
                
                // 3. Connect/Disconnect
                Button {
                    if isMounted { manager.unmount(filer) } else { manager.mount(filer) }
                } label: {
                    if isBusy {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else {
                        // Plug icons (horizontal = disconnected, slash = connected/disconnect)
                        Image(systemName: isMounted ? "network.slash" : "network")
                            .font(.system(size: 16, weight: .medium))
                            // Disconnect is Red, Connect is Standard
                            .foregroundColor(isMounted ? .red : .primary)
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
        // Double-click shortcut
        .onTapGesture(count: 2) {
            if isMounted { manager.openInFinder(filer) }
        }
        .contextMenu {
            Button(role: .destructive) { manager.removeFiler(filer.id) } label: {
                Text("Remove Filer")
            }
        }
    }
}
