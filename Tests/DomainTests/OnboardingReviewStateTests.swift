import Testing
@testable import AirplaneAI

@Suite("OnboardingReviewState")
struct OnboardingReviewStateTests {
    @Test func legalStepsBlockAdvanceUntilReviewed() {
        var state = OnboardingReviewState(currentStep: .terms)

        #expect(state.canAdvance == false)

        state.markReviewed("TermsOfUse")

        #expect(state.canAdvance == true)
    }

    @Test func completionRequiresAllDocumentsAndFinalAcknowledgment() {
        var state = OnboardingReviewState()

        state.markReviewed("TermsOfUse")
        state.markReviewed("PrivacyPolicy")
        state.markReviewed("Gemma-Notice")
        #expect(state.canComplete == false)

        state.acknowledgedFullTerms = true
        #expect(state.canComplete == true)
    }

    @Test func goNextAdvancesOnlyWhenCurrentStepAllowsIt() {
        var state = OnboardingReviewState(currentStep: .privacy)

        state.goNext()
        #expect(state.currentStep == .privacy)

        state.markReviewed("PrivacyPolicy")
        state.goNext()
        #expect(state.currentStep == .gemma)
    }
}
