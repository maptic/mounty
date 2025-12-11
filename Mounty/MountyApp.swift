import SwiftUI

@main
struct MountyApp: App {
    // Create the manager once
    @StateObject var manager = FilerManager()
    
    var body: some Scene {
        MenuBarExtra("Mounty", systemImage: "externaldrive.connected.to.line.below") {
            ContentView(manager: manager)
        }
        .menuBarExtraStyle(.window) // Allows for complex interactive UI
    }
}