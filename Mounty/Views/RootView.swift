import SwiftUI

struct RootView: View {
    @StateObject var manager = VolumeManager()
    @State private var viewMode: AppViewMode = .list

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            switch viewMode {
            case .list:
                MainListView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .leading))
            case .add:
                AddVolumeView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .trailing))
            case .settings:
                SettingsView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: viewMode)
        .frame(width: 420)
    }
}
