import SwiftUI

struct RootView: View {
    @State private var manager = VolumeManager()
    @State private var viewMode: AppViewMode = .list
    @AppStorage("mounty.maxVisibleRows") private var maxVisibleRows: Int = 5

    private let windowWidth: CGFloat = 420
    private let headerHeight: CGFloat = 52
    private let rowHeight: CGFloat = 50
    private let resizeHandleHeight: CGFloat = 8
    private let footerHeight: CGFloat = 48

    private var windowHeight: CGFloat {
        headerHeight + (CGFloat(maxVisibleRows) * rowHeight) + resizeHandleHeight + footerHeight
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()
            activeView
            speedTestDialogs
        }
        .animation(.easeOut(duration: 0.2), value: viewMode)
        .frame(width: windowWidth, height: windowHeight)
    }

    @ViewBuilder
    private var activeView: some View {
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
        case .edit(let volume):
            EditVolumeView(volume: volume, manager: manager, viewMode: $viewMode)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
        }
    }

    @ViewBuilder
    private var speedTestDialogs: some View {
        if let result = manager.speedTestResult {
            SpeedTestResultDialog(
                volumeName: manager.speedTestVolumeName,
                result: result,
                onDismiss: manager.clearSpeedTest
            )
        }

        if let error = manager.speedTestError {
            SpeedTestErrorDialog(message: error, onDismiss: manager.clearSpeedTest)
        }
    }
}

private struct SpeedTestResultDialog: View {
    let volumeName: String
    let result: SpeedTestService.Result
    let onDismiss: () -> Void
    @State private var isPresented = true

    var body: some View {
        SpeedTestOverlay(
            volumeName: volumeName,
            result: result,
            isPresented: $isPresented
        )
        .onChange(of: isPresented) { _, isPresented in
            if !isPresented { onDismiss() }
        }
    }
}

private struct SpeedTestErrorDialog: View {
    let message: String
    let onDismiss: () -> Void
    @State private var isPresented = true

    var body: some View {
        AlertOverlay(
            title: "Speed Test Failed",
            message: message,
            isPresented: $isPresented,
            isError: true
        )
        .onChange(of: isPresented) { _, isPresented in
            if !isPresented { onDismiss() }
        }
    }
}
