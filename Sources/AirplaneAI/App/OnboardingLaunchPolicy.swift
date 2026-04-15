import Foundation

enum OnboardingLaunchPolicy {
    static let completedKey = "airplane.hasCompletedOnboarding"
    static let showAgainOnNextLaunchKey = "airplane.showOnboardingOnNextLaunch"

    static func shouldPresentOnLaunch(defaults: UserDefaults) -> Bool {
        !defaults.bool(forKey: completedKey) || defaults.bool(forKey: showAgainOnNextLaunchKey)
    }

    static func scheduleForNextLaunch(defaults: UserDefaults) {
        defaults.set(true, forKey: showAgainOnNextLaunchKey)
    }

    static func markCompleted(defaults: UserDefaults) {
        defaults.set(true, forKey: completedKey)
        defaults.set(false, forKey: showAgainOnNextLaunchKey)
    }
}
