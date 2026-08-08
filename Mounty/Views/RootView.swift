import SwiftUI

struct RootView: View {
    @StateObject var manager = VolumeManager()
    @State private var viewMode: AppViewMode = .list

    var body: some View {
        ZStack(alignment: .top) {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            switch viewMode {
            case .list:
                MainListView(manager: manager, viewMode: $viewMode)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading),
                            removal: .move(edge: .leading)
                        ))
            case .add:
                AddVolumeView(manager: manager, viewMode: $viewMode)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
            case .settings:
                SettingsView(manager: manager, viewMode: $viewMode)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewMode)
        .frame(width: 420)
    }
}
