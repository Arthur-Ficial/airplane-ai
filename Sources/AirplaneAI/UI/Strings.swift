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
    static let actionRename = "Rename"
    static let sidebarTitle = "Conversations"

    // MARK: - Message actions
    static let copyMessage = "Copy message"
    static let quoteInReply = "Quote in reply"
    static let deleteMessage = "Delete message"
    static let copyCode = "Copy code"
    static let copyCodeBlock = "Copy code block"
    static let copied = "Copied"
    static let copy = "Copy"
    static let regenerateResponse = "Regenerate this response"

    // MARK: - Attachments
    static let removeAttachment = "Remove attachment"
    static let readOnly = "READ ONLY"
    static let scrollToLatest = "Scroll to latest"
    static let scrollToLatestMessage = "Scroll to latest message"
    static let contextCutoffNotice = "Older messages are outside the context window"

    // MARK: - Token counts
    static let showTokenCounts = "Show token counts on messages and in composer"

    // MARK: - Formats (use with String interpolation)
    static func tokCount(_ n: Int) -> String { "\(n) tok" }
    static func msCount(_ n: Int) -> String { "\(n) ms" }
    static func linesCount(_ n: Int) -> String { "\(n) lines" }
    static func tokensInAttachments(_ n: Int) -> String { "\(n) tokens in attachments" }
}
