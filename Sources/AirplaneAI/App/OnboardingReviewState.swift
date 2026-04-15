import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case howAIWorks
    case terms
    case privacy
    case gemma
    case agreement

    var reviewResourceName: String? {
        switch self {
        case .terms:
            "TermsOfUse"
        case .privacy:
            "PrivacyPolicy"
        case .gemma:
            "Gemma-Notice"
        default:
            nil
        }
    }
}

struct OnboardingReviewState {
    static let requiredResources: Set<String> = ["TermsOfUse", "PrivacyPolicy", "Gemma-Notice"]

    var currentStep: OnboardingStep = .welcome
    var reviewedResources: Set<String> = []
    var acknowledgedFullTerms = false

    var canAdvance: Bool {
        guard let resourceName = currentStep.reviewResourceName else {
            return true
        }
        return reviewedResources.contains(resourceName)
    }

    var canComplete: Bool {
        reviewedResources.isSuperset(of: Self.requiredResources) && acknowledgedFullTerms
    }

    mutating func markReviewed(_ resourceName: String) {
        reviewedResources.insert(resourceName)
    }

    mutating func goNext() {
        guard canAdvance else { return }
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    mutating func goBack() {
        guard let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }
}
