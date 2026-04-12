import SwiftUI

extension Notification.Name {
    static let airplaneFocusSearch = Notification.Name("airplane.focusSearch")
}

@main
struct AirplaneAIApp: App {
    @State private var wiring: AppWiring?
    @State private var bootError: String?

    var body: some Scene {
        Window("Airplane AI", id: "main") {
            RootWindow(wiring: wiring, bootError: bootError)
                .task { await boot() }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Chat") { wiring?.conversationController.newConversation() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Focus Search") {
                    NotificationCenter.default.post(name: .airplaneFocusSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView(state: wiring?.state, store: wiring?.store)
        }
    }

    @MainActor private func boot() async {
        guard wiring == nil else { return }
        do {
            let w = try AppWiring()
            await w.boot()
            wiring = w
        } catch {
            bootError = error.localizedDescription
        }
    }
}
