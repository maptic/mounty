import SwiftUI

@main
struct MountyApp: App {
    @StateObject var manager = FilerManager()
    
    var body: some Scene {
        MenuBarExtra("Mounty", systemImage: "externaldrive.connected.to.line.below") {
            ContentView(manager: manager)
        }
        .menuBarExtraStyle(.window)
    }
}
