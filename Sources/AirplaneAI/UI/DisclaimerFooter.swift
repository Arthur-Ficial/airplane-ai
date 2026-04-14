import SwiftUI

struct DisclaimerFooter: View {
    var body: some View {
        Text(L.aiDisclaimer)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}
