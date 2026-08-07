import SwiftUI

struct VolumeRow: View {
    let volume: Volume
    @ObservedObject var manager: VolumeManager
    @State private var isRowHovered = false

    var isMounted: Bool { manager.mountPaths[volume.id] != nil }
    var isBusy: Bool { manager.busyVolumes.contains(volume.id) }
    var currentPath: String { manager.mountPaths[volume.id] ?? "Disconnected" }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "server.rack")
                .font(.system(size: 22))
                .foregroundColor(
                    isMounted ? .accentColor : .secondary.opacity(0.4)
                )
                .frame(width: 26)
                .help(
                    isMounted
                        ? "Mounted at: \(currentPath)"
                        : "Server: \(volume.serverAddress)"
                )

            // Text Info
            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .font(.system(size: 13, weight: .medium))
                Text(isMounted ? currentPath : volume.serverAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .help(volume.serverAddress)

            Spacer()

            // Actions
            HStack(spacing: 4) {

                // 1. Automount Toggle
                Button {
                    manager.toggleAutomount(volume.id)
                } label: {
                    Image(
                        systemName: volume.isAutomountEnabled
                            ? "bolt.fill" : "bolt"
                    )
                    .font(.system(size: 13))
                    .foregroundColor(
                        volume.isAutomountEnabled
                            ? .orange : .secondary.opacity(0.35)
                    )
                }
                .buttonStyle(.plain)
                .iconButtonHover(padding: 3)
                .help(
                    volume.isAutomountEnabled
                        ? "Disable Automount" : "Enable Automount"
                )

                // 2. Open in Finder (Only when mounted)
                if isMounted {
                    Button {
                        manager.openInFinder(volume)
                    } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .iconButtonHover(padding: 3)
                    .help("Show in Finder")
                }

                // 3. Open in Terminal (Only when mounted)
                if isMounted {
                    Button {
                        manager.openInTerminal(volume)
                    } label: {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .iconButtonHover(padding: 3)
                    .help("Open in Terminal")
                }

                // 4. Mount / Unmount
                Button {
                    if isMounted {
                        manager.unmount(volume)
                    } else {
                        manager.mount(volume)
                    }
                } label: {
                    if isBusy {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(
                            systemName: isMounted ? "network.slash" : "network"
                        )
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(isMounted ? .red : .primary)
                    }
                }
                .buttonStyle(.plain)
                .iconButtonHover(padding: 3)
                .disabled(isBusy)
                .help(isMounted ? "Disconnect" : "Connect")
            }
        }
        .padding(.horizontal, 12)
        .background(isRowHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.1), value: isRowHovered)
        .onHover { isRowHovered = $0 }
        .onTapGesture(count: 2) {
            if isMounted { manager.openInFinder(volume) }
        }
        .contextMenu {
            Button(role: .destructive) {
                manager.removeVolume(volume.id)
            } label: {
                Text("Remove Volume")
            }
        }
    }
}
