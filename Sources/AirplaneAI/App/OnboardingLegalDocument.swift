import Foundation

struct OnboardingLegalDocument: Identifiable, Equatable {
    let title: String
    let resourceName: String
    let summaryIntro: String
    let summaryBullets: [String]

    var id: String { resourceName }

    static let terms = OnboardingLegalDocument(
        title: "Terms of Use",
        resourceName: "TermsOfUse",
        summaryIntro: "Important summary only. The full Terms of Use below control your use of Airplane AI.",
        summaryBullets: [
            "Airplane AI is licensed, not sold.",
            "AI output can be wrong, incomplete, fabricated, harmful, or infringing.",
            "You must verify important information before relying on it.",
            "The developer is not liable for losses, claims, or damages caused by your use of AI output."
        ]
    )

    static let privacy = OnboardingLegalDocument(
        title: "Privacy Policy",
        resourceName: "PrivacyPolicy",
        summaryIntro: "Important summary only. The full Privacy Policy below applies in full.",
        summaryBullets: [
            "Airplane AI is designed to run locally on your Mac.",
            "Conversations are stored locally in the app sandbox.",
            "No analytics, telemetry, or advertising SDKs are included.",
            "Voice, image, and document processing use Apple system frameworks."
        ]
    )

    static let gemma = OnboardingLegalDocument(
        title: "Gemma Model Terms",
        resourceName: "Gemma-Notice",
        summaryIntro: "Important summary only. The Gemma terms below apply to the bundled model used by Airplane AI.",
        summaryBullets: [
            "Airplane AI uses a Gemma-based open model distributed under Google’s Gemma terms.",
            "Gemma is a machine-learning model family that generates text from your prompts.",
            "Google prohibits uses such as copyright infringement, scams, malware, harassment, hate, violence, explicit sexual content, deceptive impersonation, and unauthorized professional advice.",
            "You must follow the Gemma terms and prohibited-use policy when using the model or its output."
        ]
    )

    static let all: [OnboardingLegalDocument] = [.terms, .privacy, .gemma]
}
