import SwiftUI

// Single-window macOS app. Spec §14: use Window, not WindowGroup.
// UI views are filled in during Milestone 7; this file is the stable entry point.
@main
struct AirplaneAIApp: App {
    var body: some Scene {
        Window("Airplane AI", id: "main") {
            RootWindow()
        }
        .windowResizability(.contentSize)
    }
}
