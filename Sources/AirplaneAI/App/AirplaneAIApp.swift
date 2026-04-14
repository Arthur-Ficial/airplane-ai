import SwiftUI
import AppKit
import Darwin

extension Notification.Name {
    static let airplaneFocusSearch = Notification.Name("airplane.focusSearch")
    static let airplaneOpenSettings = Notification.Name("airplane.openSettings")
    static let airplaneMicTranscript = Notification.Name("airplane.micTranscript")
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

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        strip()
        // NSTextView re-injects the Format menu when the composer becomes first
        // responder. Re-strip on every activation and every menu-bar open.
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(stripNotification(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        nc.addObserver(self, selector: #selector(stripNotification(_:)), name: NSWindow.didBecomeKeyNotification, object: nil)
        nc.addObserver(self, selector: #selector(stripNotification(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
        NSApp.mainMenu?.delegate = self
    }

    // Called just before the top menu bar is about to open — final strip.
    func menuNeedsUpdate(_ menu: NSMenu) { strip() }

    @objc private func stripNotification(_ notification: Notification) {
        strip()
    }

    private func strip() {
        guard let main = NSApp.mainMenu else { return }
        MenuBarSanitizer.removeIrrelevantMenus(from: main)
    }
}

@main
struct AirplaneEntry {
    static func main() async {
        let args = ProcessInfo.processInfo.arguments
        if CLIArguments.isCLIInvocation(arguments: args) {
            let cliArgs = Array(args.dropFirst())
            let exitCode = await HeadlessCLIBoot.run(arguments: cliArgs)
            exit(exitCode)
        }
        AirplaneAIApp.main()
    }
}

struct AirplaneAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var wiring: AppWiring?
    @State private var bootError: String?

    var body: some Scene {
        Window("Airplane AI", id: "main") {
            RootWindow(wiring: wiring, bootError: bootError)
                .onAppear { Task { await launch() } }
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

    @MainActor private func launch() async {
        if SampleConversationSeeder.shouldRun() {
            do {
                try await SampleConversationSeeder.run()
            } catch {
                bootError = error.localizedDescription
            }
            NSApp.terminate(nil)
            exit(bootError == nil ? 0 : 1)
        }

        await boot()
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
