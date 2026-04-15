import SwiftUI

struct LegalTextView: View {
    let title: String
    let resourceName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Padding.large) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(loadText())
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding(Metrics.Padding.large * 2)
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 600)
    }

    private func loadText() -> String {
        LegalDocumentLoader.load(resourceName: resourceName, fallbackTitle: title)
    }
}
