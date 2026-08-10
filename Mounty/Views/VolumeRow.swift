import SwiftUI

struct VolumeRow: View {
    let volume: Volume
    var manager: VolumeManager
    var onEdit: () -> Void = {}
    @State private var isRowHovered = false

    var isMounted: Bool { manager.mountPaths[volume.id] != nil }
    var isBusy: Bool { manager.busyVolumes.contains(volume.id) }
    var isTesting: Bool { manager.speedTestVolumeId == volume.id && manager.isRunningSpeedTest }
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
                .animation(.easeOut(duration: 0.2), value: isMounted)
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
                .iconButtonHover(padding: 3)
                .help(
                    volume.isAutomountEnabled
                        ? "Disable Automount" : "Enable Automount"
                )
                .disabled(isBusy || isTesting || manager.isClearingVolumes)

                // 2. Open in Finder (Only when mounted)
                if isMounted {
                    Button {
                        manager.openInFinder(volume)
                    } label: {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
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
                    .iconButtonHover(padding: 3)
                    .help("Open in Terminal")
                }

                // 4. Mount / Unmount (also shows speed-test progress)
                Button {
                    if isMounted {
                        manager.unmount(volume)
                    } else {
                        manager.mount(volume)
                    }
                } label: {
                    if isBusy || isTesting {
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
                .iconButtonHover(padding: 3)
                .disabled(isBusy || isTesting)
                .help(isTesting ? "Speed test running…" : (isMounted ? "Disconnect" : "Connect"))
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(isRowHovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.1), value: isRowHovered)
        .onHover { isRowHovered = $0 }
        // simultaneousGesture lets the double-tap and child Button taps resolve
        // without blocking each other, eliminating the click-delay on Buttons.
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                if isMounted { manager.openInFinder(volume) }
            }
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit Volume…", systemImage: "pencil")
            }
            .disabled(isBusy || isTesting || manager.isClearingVolumes)

            if isMounted {
                Button {
                    manager.runSpeedTest(for: volume)
                } label: {
                    Label("Measure Speed…", systemImage: "speedometer")
                }
                .disabled(isBusy || manager.isRunningSpeedTest || manager.isClearingVolumes)
            }

            Divider()

            Button(role: .destructive) {
                manager.removeVolume(volume.id)
            } label: {
                Label("Remove Volume", systemImage: "trash")
            }
            .disabled(isBusy || isTesting || manager.isClearingVolumes)
        }
    }
}
