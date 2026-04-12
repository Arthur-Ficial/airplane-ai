import Foundation

// SwiftPM does not compile .xcstrings. v0.1.0 ships English-only literals as SSOT.
// When we migrate to an Xcode project for App Store submission, swap to NSLocalizedString.
enum L {
    static let tagline = "AI that never phones home."
    static let modelVerifying = "Verifying AI model…"
    static let modelLoading = "Loading AI model…"
    static let modelWarming = "Warming up…"
    static let modelReady = "Ready"
    static let modelCorruptTitle = "AI model is damaged"
    static let modelCorruptBody = "Please delete and re-install Airplane AI from the App Store."
    static let memoryTitle = "Not enough memory"
    static let diskTitle = "Not enough free disk space"
    static let contextTitle = "Message is too long"
    static let chatPlaceholder = "Ask anything…"
    static let chatGenerating = "Thinking…"
    static let chatInterrupted = "Interrupted"
    static let actionSend = "Send"
    static let actionStop = "Stop"
    static let actionRetry = "Retry"
    static let actionNewChat = "New Chat"
    static let actionDelete = "Delete"
    static let sidebarTitle = "Conversations"
}
