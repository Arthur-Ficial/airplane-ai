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

    // MARK: - Mic / Speech
    static let micVoiceInput = "Voice input"
    static let micStopRecording = "Stop recording"
    static let micProcessing = "Processing voice…"
    static let micPermissionDenied = "Microphone or speech recognition permission denied. Open System Settings to grant access."
    static let micUnavailable = "On-device speech recognition is not available on this Mac."
    static let privacySpeechOnDevice = "Speech transcription runs on-device via Apple SFSpeechRecognizer. No audio leaves your Mac."

    // MARK: - Disclaimer
    static let aiDisclaimer = "AI can make mistakes. Check important info."

    // MARK: - Onboarding
    static let onboardingWelcomeTitle = "Welcome to Airplane AI"
    static let onboardingWelcomeSubtitle = "Your private, offline AI assistant"
    static let onboardingHowAITitle = "How AI Works"
    static let onboardingBullet1 = "This AI runs entirely on your Mac. Nothing leaves your device."
    static let onboardingBullet2 = "AI generates responses based on patterns in training data. It doesn\u{2019}t truly \u{2018}know\u{2019} things."
    static let onboardingBullet3 = "AI can be wrong, make things up, or miss context. Always verify important information."
    static let onboardingAgreementTitle = "Before You Begin"
    static let onboardingAgreementSubtitle = "AI is a tool, not an oracle."
    static let onboardingAcceptTerms = "I accept the Terms of Use"
    static let onboardingAcceptPrivacy = "I accept the Privacy Policy"
    static let onboardingAcceptDisclaimer = "I understand AI can make mistakes and I will verify important information"
    static let onboardingGetStarted = "Get Started"
    static let onboardingReadTerms = "Read Terms of Use"
    static let onboardingReadPrivacy = "Read Privacy Policy"
    static let onboardingNext = "Next"
    static let onboardingBack = "Back"
}
