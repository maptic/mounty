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
            case .logs:
                LogsView(manager: manager, viewMode: $viewMode)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .trailing)
                        ))
            }

            // Speed test overlays — rendered above any active view.
            if let result = manager.speedTestResult {
                SpeedTestOverlay(
                    volumeName: manager.speedTestVolumeName,
                    result: result,
                    isPresented: Binding(
                        get: { manager.speedTestResult != nil },
                        set: { if !$0 { manager.clearSpeedTest() } }
                    )
                )
            }

            if let errMsg = manager.speedTestError {
                AlertOverlay(
                    title: "Speed Test Failed",
                    message: errMsg,
                    isPresented: Binding(
                        get: { manager.speedTestError != nil },
                        set: { if !$0 { manager.clearSpeedTest() } }
                    ),
                    isError: true
                )
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewMode)
        .frame(width: 420)
    }
}
