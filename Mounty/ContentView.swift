import SwiftUI

enum AppViewMode { case list, add }

struct ContentView: View {
    @StateObject var manager: FilerManager
    @State private var viewMode: AppViewMode = .list
    
    let width: CGFloat = 340
    let height: CGFloat = 350
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            if viewMode == .list {
                MainListView(manager: manager, viewMode: $viewMode)
            } else {
                AddFilerView(manager: manager, viewMode: $viewMode)
            }
        }
        .frame(width: width, height: height)
    }
}

struct MainListView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Mounty").font(.headline)
                Spacer()
                Toggle("Start at Login", isOn: $manager.launchAtLogin)
                    .controlSize(.mini).toggleStyle(.switch).font(.caption)
            }
            .padding(12)
            Divider()
            
            // List
            if manager.filers.isEmpty {
                VStack(spacing: 15) {
                    Spacer()
                    Image(systemName: "server.rack").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("No Filers Configured").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(manager.filers) { filer in
                            FilerRow(filer: filer, manager: manager)
                            Divider()
                        }
                    }
                }
            }
            Spacer()
            Divider()
            
            // Footer
            HStack {
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.borderless).foregroundColor(.secondary).font(.caption)
                Spacer()
                Button(action: { viewMode = .add }) { Label("Add Filer", systemImage: "plus") }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(10)
        }
    }
}

struct FilerRow: View {
    let filer: Filer
    @ObservedObject var manager: FilerManager
    
    var isMounted: Bool { return manager.mountPaths[filer.id] != nil }
    var isBusy: Bool { return manager.pendingOperations.contains(filer.id) }
    var currentPath: String { return manager.mountPaths[filer.id] ?? "Disconnected" }
    
    var body: some View {
        HStack(spacing: 10) {
            // Dot
            Circle()
                .fill(isMounted ? Color.green : (isBusy ? Color.orange : Color.red))
                .frame(width: 8, height: 8)
                .help(isMounted ? "Mounted at \(currentPath)" : (isBusy ? "Connecting..." : "Not Mounted"))
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(filer.name).font(.system(size: 13, weight: .medium))
                Text(isMounted ? currentPath : filer.serverAddress)
                    .font(.caption2).foregroundColor(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            
            // Actions
            HStack(spacing: 6) {
                
                if isMounted {
                    // Terminal
                    Button { manager.openTerminal(for: filer) } label: {
                        Image(systemName: "terminal.fill").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless).help("Open Terminal here")
                    
                    // Copy
                    Button { manager.copyPath(filer) } label: {
                        Image(systemName: "doc.on.doc").font(.system(size: 11))
                    }
                    .buttonStyle(.borderless).help("Copy Path")
                }
                
                // Automount Toggle
                Button { manager.toggleAutomount(for: filer.id) } label: {
                    Image(systemName: filer.isAutomountEnabled ? "bolt.fill" : "bolt.slash")
                        .foregroundColor(filer.isAutomountEnabled ? .orange : .secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless).help("Toggle Automount")
                
                // Connect / Disconnect
                if isMounted {
                    Button { manager.unmount(filer) } label: {
                        if isBusy {
                            ProgressView().controlSize(.mini).scaleEffect(0.6)
                        } else {
                            Image(systemName: "network.slash").font(.system(size: 11, weight: .bold)).foregroundColor(.white).padding(4)
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.mini).help("Disconnect").disabled(isBusy)
                } else {
                    Button { manager.mount(filer) } label: {
                        if isBusy {
                            ProgressView().controlSize(.mini).scaleEffect(0.6)
                        } else {
                            Image(systemName: "network").font(.system(size: 11, weight: .bold)).padding(4)
                        }
                    }
                    .buttonStyle(.bordered).controlSize(.mini).help("Connect").disabled(isBusy)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove Filer") { manager.removeFiler(id: filer.id) }
        }
    }
}
