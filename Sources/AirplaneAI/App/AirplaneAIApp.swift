import SwiftUI
import AppKit

extension Notification.Name {
    static let airplaneFocusSearch = Notification.Name("airplane.focusSearch")
    static let airplaneOpenSettings = Notification.Name("airplane.openSettings")
}

// Removes menus that NSTextView's responder chain adds automatically
// (Format/Font/Styles) — irrelevant for a plain-text composer.
enum MenuBarSanitizer {
    // Menus to strip wholesale.
    static let menusToRemove: [String] = ["Format"]

    // Pure function — mutates the passed NSMenu, returns the count of removed items.
    @discardableResult
    static func removeIrrelevantMenus(from menu: NSMenu) -> Int {
        var removed = 0
        for title in menusToRemove {
            if let item = menu.items.first(where: { $0.title == title }) {
                menu.removeItem(item)
                removed += 1
            }
        }
        return removed
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let main = NSApp.mainMenu {
            MenuBarSanitizer.removeIrrelevantMenus(from: main)
        }
    }
}

@main
struct AirplaneAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                    NotificationCenter.default.post(name: .airplaneOpenSettings, object: nil)
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
