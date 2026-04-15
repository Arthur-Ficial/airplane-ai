import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var reviewState = OnboardingReviewState()

    private let documents = OnboardingLegalDocument.all
    private let pageCount = OnboardingStep.allCases.count

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch reviewState.currentStep {
                case .welcome:
                    OnboardingWelcomePage()
                case .howAIWorks:
                    OnboardingHowAIWorksPage()
                case .terms:
                    legalPage(for: "TermsOfUse")
                case .privacy:
                    legalPage(for: "PrivacyPolicy")
                case .gemma:
                    legalPage(for: "Gemma-Notice")
                case .agreement:
                    OnboardingAgreementPage(
                        acknowledgedFullTerms: $reviewState.acknowledgedFullTerms,
                        canComplete: reviewState.canComplete,
                        onComplete: onComplete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            navigationBar.padding(Metrics.Padding.large)
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 520)
        .animation(.easeInOut(duration: 0.3), value: reviewState.currentStep)
    }

    private var navigationBar: some View {
        HStack {
            Button(L.onboardingBack) { reviewState.goBack() }
                .disabled(reviewState.currentStep == .welcome)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == reviewState.currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if reviewState.currentStep != .agreement {
                Button(L.onboardingNext) { reviewState.goNext() }
                    .disabled(!reviewState.canAdvance)
            } else {
                // Invisible placeholder to keep dots centered; the AgreementPage owns "Get Started".
                Button(L.onboardingNext) {}
                    .hidden()
            }
        }
    }

    @ViewBuilder
    private func legalPage(for resourceName: String) -> some View {
        if let document = documents.first(where: { $0.resourceName == resourceName }) {
            OnboardingLegalReviewPage(
                document: document,
                reviewed: Binding(
                    get: { reviewState.reviewedResources.contains(resourceName) },
                    set: { if $0 { reviewState.markReviewed(resourceName) } }
                )
            )
        }
    }
}
