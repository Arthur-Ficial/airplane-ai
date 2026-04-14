import SwiftUI

struct OnboardingWelcomePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            AirplaneGlyph(size: 64)
            Text(L.onboardingWelcomeTitle)
                .font(.largeTitle.weight(.semibold))
            Text(L.tagline)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(L.onboardingWelcomeSubtitle)
                .font(.callout)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
