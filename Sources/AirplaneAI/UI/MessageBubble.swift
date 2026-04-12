import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if message.status == .interrupted {
                    Label(String(localized: "chat.interrupted"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                MarkdownText(text: message.content.isEmpty ? " " : message.content)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var background: Color {
        message.role == .user ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)
    }

    private var accessibilityLabel: String {
        let role = message.role == .user ? "You" : "Assistant"
        return "\(role): \(message.content)"
    }
}
