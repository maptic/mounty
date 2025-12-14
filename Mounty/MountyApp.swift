import SwiftUI

@main
struct MountyApp: App {
    // Initialize the Manager once at the app lifecycle root
    @StateObject var manager = FilerManager()
    
    var body: some Scene {
        // MenuBarExtra creates the menu bar item
        MenuBarExtra("Mounty", systemImage: "externaldrive.connected.to.line.below") {
            RootView(manager: manager)
        }
        .menuBarExtraStyle(.window) // Allows for a custom SwiftUI view
    }
}
