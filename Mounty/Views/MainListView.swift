import SwiftUI

struct MainListView: View {
    @ObservedObject var manager: FilerManager
    @Binding var viewMode: AppViewMode

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Mounty").font(.headline).fontWeight(.bold)
                Spacer()
                Button {
                    viewMode = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain).help("Settings")
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.regularMaterial)

            Divider()

            // Content
            if manager.filers.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "externaldrive.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    Text("No filers configured").foregroundColor(.secondary)
                    Button("Add Your First Filer") { viewMode = .add }
                        .buttonStyle(.borderedProminent)
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

            Divider()

            // Footer
            HStack {
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain).foregroundColor(.secondary).font(
                        .caption
                    )
                Spacer()
                Button {
                    viewMode = .add
                } label: {
                    Label("Add Filer", systemImage: "plus")
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(12).background(.regularMaterial)
        }
        // Error Alert
        .alert("Error", isPresented: $manager.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.lastError ?? "Unknown error")
        }
    }
}
