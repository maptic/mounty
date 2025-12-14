import SwiftUI

struct RootView: View {
    @StateObject var manager: FilerManager
    @State private var viewMode: AppViewMode = .list

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()

            switch viewMode {
            case .list:
                MainListView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .leading))
            case .add:
                AddFilerView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .trailing))
            case .settings:
                SettingsView(manager: manager, viewMode: $viewMode)
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(width: 340, height: 420)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.8),
            value: viewMode
        )
    }
}
