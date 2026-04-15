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
    static let micMicrophonePermissionDenied = "Microphone access denied. Open System Settings to allow audio input."
    static let micSpeechPermissionDenied = "Speech recognition access denied. Open System Settings to allow speech recognition."
    static let micUnavailable = "Speech recognition is not available for the selected language on this Mac."
    static let micRecognizerBusy = "Speech recognition is temporarily unavailable. Try again in a moment."
    static let micNoInputDevice = "No usable microphone input was found."
    static func micStartFailed(_ details: String) -> String { "Failed to start microphone input: \(details)" }
    static func micRecognitionFailed(_ details: String) -> String { "Speech recognition failed: \(details)" }
    static let privacySpeechOnDevice = "Voice input uses Apple speech recognition on your Mac."
    static let audioTabTitle = "Audio"
    static let audioHeroSubtitle = "Choose one language for voice input and spoken replies. Airplane AI uses the best available Apple voice automatically."
    static let audioLanguageTitle = "Audio language"
    static let audioLanguageSubtitle = "Airplane AI listens and speaks in this language whenever Apple supports it."
    static let audioOutputTitle = "Spoken replies"
    static let audioOutputSubtitle = "Turn this on if you want Airplane AI to read assistant messages out loud."
    static let audioSearchPlaceholder = "Search languages"
    static let audioOutputToggle = "Read assistant replies out loud"
    static let audioBestVoiceLabel = "Best voice"

    // MARK: - Disclaimer
    static let aiDisclaimer = "AI can make mistakes. Check important info."

    // MARK: - Onboarding
    static let onboardingWelcomeTitle = "Welcome to Airplane AI"
    static let onboardingWelcomeSubtitle = "Your private, offline AI assistant"
    static let onboardingHowAITitle = "How AI Works"
    static let onboardingBullet1 = "This AI runs entirely on your Mac. Nothing leaves your device."
    static let onboardingBullet2 = "Airplane AI uses a Gemma-based open model. It predicts text from patterns in training data; it does not truly know or verify facts."
    static let onboardingBullet3 = "AI can be wrong, harmful, misleading, infringing, or unsafe. Always verify important information before you rely on it or share it."
    static let onboardingAgreementTitle = "Before You Begin"
    static let onboardingAgreementSubtitle = "These summaries are highlights only. The full legal documents you reviewed above apply."
    static let onboardingGetStarted = "Get Started"
    static let onboardingReadTerms = "Read Terms of Use"
    static let onboardingReadPrivacy = "Read Privacy Policy"
    static let onboardingNext = "Next"
    static let onboardingBack = "Back"
}
