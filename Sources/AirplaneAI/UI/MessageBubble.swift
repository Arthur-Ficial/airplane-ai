import SwiftUI
import AppKit

struct MessageBubble: View, Equatable {
    let message: ChatMessage
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopied = false
    @State private var copyHover = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 60) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                content
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                footer
            }
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var content: some View {
        if message.status == .streaming {
            Text(message.content.isEmpty ? " " : message.content)
                .font(.system(size: 14)).lineSpacing(3).textSelection(.enabled)
        } else {
            MarkdownText(text: message.content.isEmpty ? " " : message.content)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if message.status == .interrupted {
                Label(L.chatInterrupted, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10)).foregroundStyle(.orange)
            }
            if !message.content.isEmpty, message.status != .streaming {
                Button(action: copy) {
                    Text(showCopied ? "Copied" : "Copy")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(showCopied ? .green : copyHover ? .blue : .secondary)
                }
                .buttonStyle(.borderless)
                .onHover { copyHover = $0 }
            }
        }
        .padding(.horizontal, 4)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
    }

    private var background: Color {
        switch message.role {
        case .user: Color.accentColor
        case .assistant: colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.93)
        case .system: Color.orange.opacity(0.12)
        }
    }

    nonisolated static func == (l: Self, r: Self) -> Bool { l.message == r.message }
}
