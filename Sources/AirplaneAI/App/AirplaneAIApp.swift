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
            // File menu — replace default 'New' items with 'New Chat' + 'Focus Search'.
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { wiring?.conversationController.newConversation() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Focus Search") {
                    NotificationCenter.default.post(name: .airplaneFocusSearch, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            // Airplane AI has no files — strip the default Save/Open/Print items.
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .importExport) { }
            CommandGroup(replacing: .printItem) { }
            // No rich-text formatting anywhere in the app.
            CommandGroup(replacing: .textFormatting) { }

            // Help → GitHub instead of an empty help book.
            CommandGroup(replacing: .help) {
                Link("Airplane AI on GitHub",
                     destination: URL(string: "https://github.com/franzenzenhofer/airplane-ai")!)
            }

            // App > About Airplane AI routes to the Settings About tab.
            CommandGroup(replacing: .appInfo) {
                Button("About Airplane AI") {
                    if #available(macOS 14, *) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } else {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
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
