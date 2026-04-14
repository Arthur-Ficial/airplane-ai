import SwiftUI

struct OnboardingAgreementPage: View {
    let onComplete: () -> Void

    @State private var acceptTerms = false
    @State private var acceptPrivacy = false
    @State private var acceptDisclaimer = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    private var allAccepted: Bool {
        acceptTerms && acceptPrivacy && acceptDisclaimer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.onboardingAgreementTitle)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(L.onboardingAgreementSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)

            Toggle(isOn: $acceptTerms) {
                Text(L.onboardingAcceptTerms).font(.callout)
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $acceptPrivacy) {
                Text(L.onboardingAcceptPrivacy).font(.callout)
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $acceptDisclaimer) {
                Text(L.onboardingAcceptDisclaimer).font(.callout)
            }
            .toggleStyle(.checkbox)

            HStack(spacing: 12) {
                Button(L.onboardingReadTerms) { showTerms = true }
                    .buttonStyle(.link)
                Button(L.onboardingReadPrivacy) { showPrivacy = true }
                    .buttonStyle(.link)
            }
            .padding(.top, 4)

            Spacer()

            Button(L.onboardingGetStarted) { onComplete() }
                .buttonStyle(.borderedProminent)
                .disabled(!allAccepted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Metrics.Padding.large * 2)
        .sheet(isPresented: $showTerms) {
            LegalTextView(title: L.onboardingReadTerms, resourceName: "TermsOfUse")
        }
        .sheet(isPresented: $showPrivacy) {
            LegalTextView(title: L.onboardingReadPrivacy, resourceName: "PrivacyPolicy")
        }
    }
}
