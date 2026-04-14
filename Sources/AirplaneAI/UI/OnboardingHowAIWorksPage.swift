import SwiftUI

struct OnboardingHowAIWorksPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L.onboardingHowAITitle)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
            bulletRow(icon: "airplane", text: L.onboardingBullet1)
            bulletRow(icon: "brain.head.profile", text: L.onboardingBullet2)
            bulletRow(icon: "exclamationmark.triangle", text: L.onboardingBullet3)
            Spacer()
        }
        .padding(Metrics.Padding.large * 2)
    }

    private func bulletRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Palette.accent)
                .frame(width: 24, height: 24)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
