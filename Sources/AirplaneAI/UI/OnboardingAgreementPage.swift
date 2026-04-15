import SwiftUI

struct OnboardingAgreementPage: View {
    @Binding var acknowledgedFullTerms: Bool
    let canComplete: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L.onboardingAgreementTitle)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            Text(L.onboardingAgreementSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 10) {
                summaryRow("Airplane AI uses a Gemma-based open model to generate text from your prompts.")
                summaryRow("AI output can be wrong, harmful, infringing, misleading, or unsafe if you rely on it without review.")
                summaryRow("You are responsible for verifying important output and for how you use the app and its generated content.")
                summaryRow("The developer does not accept liability for losses, claims, or damages caused by your reliance on AI output.")
            }

            Toggle(isOn: $acknowledgedFullTerms) {
                Text("I reviewed the Terms of Use, Privacy Policy, and Gemma model terms above. I understand the summaries are only highlights, the full documents apply, AI output can be wrong or harmful, and I accept that I am responsible for my use of the app and its output.")
                    .font(.callout)
            }
            .toggleStyle(.checkbox)

            Spacer()

            Button(L.onboardingGetStarted) { onComplete() }
                .buttonStyle(.borderedProminent)
                .disabled(!canComplete)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Metrics.Padding.large * 2)
    }

    private func summaryRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
