import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: OnboardingWelcomePage()
                case 1: OnboardingHowAIWorksPage()
                default: OnboardingAgreementPage(onComplete: onComplete)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            navigationBar.padding(Metrics.Padding.large)
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 520)
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    private var navigationBar: some View {
        HStack {
            Button(L.onboardingBack) { page -= 1 }
                .disabled(page == 0)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            Spacer()

            if page < pageCount - 1 {
                Button(L.onboardingNext) { page += 1 }
            } else {
                // Invisible placeholder to keep dots centered; the AgreementPage owns "Get Started".
                Button(L.onboardingNext) {}
                    .hidden()
            }
        }
    }
}
