import SwiftUI

@main
@MainActor
struct MountyApp: App {

    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static let paddedIcon: NSImage = {
        guard let image = NSImage(named: "MenuIcon") else { return NSImage() }

        let targetHeight: CGFloat = 15
        let ratio = image.size.width / image.size.height
        let targetWidth = targetHeight * ratio

        image.size = NSSize(width: targetWidth, height: targetHeight)
        image.isTemplate = true

        return image
    }()

    var body: some Scene {
        MenuBarExtra {
            if isRunningTests {
                EmptyView()
            } else {
                RootView()
            }
        } label: {
            Image(nsImage: Self.paddedIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
