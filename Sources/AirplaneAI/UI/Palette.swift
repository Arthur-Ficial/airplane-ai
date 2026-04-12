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

    // Status dot.
    static let statusReady = Color.green
    static let statusLoading = Color.blue
    static let statusError = Color.red
}
