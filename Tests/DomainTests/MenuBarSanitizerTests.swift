import Foundation
import AppKit
import Testing
@testable import AirplaneAI

@MainActor
@Suite("MenuBarSanitizer")
struct MenuBarSanitizerTests {
    private func makeMenu(titles: [String]) -> NSMenu {
        let root = NSMenu(title: "")
        for t in titles {
            root.addItem(NSMenuItem(title: t, action: nil, keyEquivalent: ""))
        }
        return root
    }

    @Test func removesFormatMenu() {
        let menu = makeMenu(titles: ["Apple", "Airplane AI", "File", "Edit", "Format", "View", "Window", "Help"])
        let n = MenuBarSanitizer.removeIrrelevantMenus(from: menu)
        #expect(n == 1)
        #expect(!menu.items.map(\.title).contains("Format"))
    }

    @Test func keepsOtherMenus() {
        let expected = ["Apple", "Airplane AI", "File", "Edit", "View", "Window", "Help"]
        let menu = makeMenu(titles: ["Apple", "Airplane AI", "File", "Edit", "Format", "View", "Window", "Help"])
        MenuBarSanitizer.removeIrrelevantMenus(from: menu)
        #expect(menu.items.map(\.title) == expected)
    }

    @Test func noOpWhenFormatAbsent() {
        let menu = makeMenu(titles: ["Apple", "File", "Edit"])
        let n = MenuBarSanitizer.removeIrrelevantMenus(from: menu)
        #expect(n == 0)
        #expect(menu.items.count == 3)
    }

    @Test func declaresFormatAsMenuToRemove() {
        #expect(MenuBarSanitizer.menusToRemove.contains("Format"))
    }
}
