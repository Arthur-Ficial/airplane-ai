import SwiftUI

// Top banner for non-fatal errors. Auto-hides after 5s; tap × to dismiss early.
struct Toast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.horizontal, Metrics.Padding.regular)
        .padding(.vertical, Metrics.Padding.small)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.Radius.regular)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.regular))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
