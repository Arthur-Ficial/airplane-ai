import Foundation
import Testing
@testable import AirplaneAI

@Suite("OnboardingLaunchPolicy")
struct OnboardingLaunchPolicyTests {
    @Test func firstLaunchRequiresPresentation() {
        let defaults = makeDefaults()

        #expect(OnboardingLaunchPolicy.shouldPresentOnLaunch(defaults: defaults) == true)
    }

    @Test func completedLaunchStaysHiddenUntilExplicitlyScheduled() {
        let defaults = makeDefaults()
        OnboardingLaunchPolicy.markCompleted(defaults: defaults)

        #expect(OnboardingLaunchPolicy.shouldPresentOnLaunch(defaults: defaults) == false)

        OnboardingLaunchPolicy.scheduleForNextLaunch(defaults: defaults)

        #expect(OnboardingLaunchPolicy.shouldPresentOnLaunch(defaults: defaults) == true)
    }

    @Test func markCompletedClearsNextLaunchRequest() {
        let defaults = makeDefaults()

        OnboardingLaunchPolicy.scheduleForNextLaunch(defaults: defaults)
        #expect(defaults.bool(forKey: OnboardingLaunchPolicy.showAgainOnNextLaunchKey) == true)

        OnboardingLaunchPolicy.markCompleted(defaults: defaults)

        #expect(defaults.bool(forKey: OnboardingLaunchPolicy.completedKey) == true)
        #expect(defaults.bool(forKey: OnboardingLaunchPolicy.showAgainOnNextLaunchKey) == false)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "OnboardingLaunchPolicyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
