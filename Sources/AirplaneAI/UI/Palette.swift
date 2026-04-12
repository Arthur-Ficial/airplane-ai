import SwiftUI

// SSOT for app colors. Resolves per-scheme automatically for light/dark.
// Every UI file must read colors from here — no inline Color(white: ...) anywhere else.
enum Palette {
    static let accent = Color.accentColor

    // Chat bubbles.
    static func userBubble() -> Color { Color.accentColor }
    static func assistantBubble(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.18) : Color(white: 0.93)
    }
    static func systemBubble() -> Color { Color.orange.opacity(0.12) }

    // Code blocks.
    static func codeBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.15) : Color(white: 0.93)
    }
    static func codeHeader(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.12) : Color(white: 0.88)
    }
    // High-transparency border outlining every fenced code block.
    // Dark: white @ ~18%; Light: black @ ~18%.
    static func codeBlockBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.18)
    }

    // Status dot.
    static let statusReady = Color.green
    static let statusLoading = Color.blue
    static let statusError = Color.red

    // Inline `code` pill.
    static func inlineCodeBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.28) : Color(white: 0.88)
    }
    static func inlineCodeForeground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.60, green: 0.82, blue: 1.0)
                        : Color(red: 0.02, green: 0.30, blue: 0.70)
    }
}
