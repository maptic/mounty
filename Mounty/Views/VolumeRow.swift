import SwiftUI

struct VolumeRow: View {
    let volume: Volume
    @ObservedObject var manager: VolumeManager

    var isMounted: Bool { manager.mountPaths[volume.id] != nil }
    var isBusy: Bool { manager.busyVolumes.contains(volume.id) }
    var currentPath: String { manager.mountPaths[volume.id] ?? "Disconnected" }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 24))
                .foregroundColor(
                    isMounted ? .accentColor : .secondary.opacity(0.5)
                )
                .help(
                    isMounted
                        ? "Mounted at: \(currentPath)"
                        : "Server: \(volume.serverAddress)"
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name).font(.system(size: 13, weight: .medium))
                Text(isMounted ? currentPath : volume.serverAddress)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            .help(volume.serverAddress)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    manager.toggleAutomount(volume.id)
                } label: {
                    Image(
                        systemName: volume.isAutomountEnabled
                            ? "bolt.fill" : "bolt"
                    )
                    .font(.system(size: 14))
                    .foregroundColor(
                        volume.isAutomountEnabled
                            ? .orange : .secondary.opacity(0.3)
                    )
                }
                .buttonStyle(.plain).help(
                    volume.isAutomountEnabled
                        ? "Disable Automount" : "Enable Automount"
                )

                if isMounted {
                    Button {
                        manager.openInTerminal(volume)
                    } label: {
                        Image(systemName: "terminal.fill").font(
                            .system(size: 12)
                        ).foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Open in Terminal")

                    Button {
                        manager.openInFinder(volume)
                    } label: {
                        Image(systemName: "folder.fill").font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain).help("Show in Finder")
                }

                Button {
                    if isMounted {
                        manager.unmount(volume)
                    } else {
                        manager.mount(volume)
                    }
                } label: {
                    if isBusy {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else {
                        Image(
                            systemName: isMounted ? "network.slash" : "network"
                        )
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isMounted ? .red : .primary)
                    }
                }
                .buttonStyle(.plain).disabled(isBusy)
                .help(isMounted ? "Disconnect" : "Connect")
            }
        }
        .padding(.horizontal, 12)
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
