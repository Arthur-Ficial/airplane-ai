import SwiftUI
import AppKit

struct MessageBubble: View, Equatable {
    let message: ChatMessage
    var isLastAssistant: Bool = false
    var onRegenerate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var showCopied = false
    @State private var copyHover = false
    @State private var hover = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.role == .user { Spacer(minLength: 60) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                VStack(alignment: .leading, spacing: 0) { content }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                footer
            }
            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .onHover { hover = $0 }
        .contextMenu {
            Button("Copy message") { copy() }
            if let onDelete {
                Button("Delete message", role: .destructive, action: onDelete)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        // Retroactively clean any template leaks from messages persisted before
        // the engine-side filter was wired in. No migration needed.
        let (cleanContent, _) = OutputSanitizer.stripLeakingMarkers(message.content)
        if message.status == .streaming {
            Text(cleanContent.isEmpty ? " " : cleanContent)
                .font(.body).textSelection(.enabled)
        } else {
            let cached = MarkdownRenderer.cached(cleanContent)
            if cached.isJSON {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(cached.prettyJSON)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(cached.blocks) { block in
                        switch block.kind {
                        case .text:
                            Text(block.rendered ?? AttributedString(block.content))
                                .font(.body).textSelection(.enabled)
                        case .code:
                            codeBlock(block)
                        }
                    }
                }
            }
        }
    }

    private func codeBlock(_ block: MarkdownRenderer.Block) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = block.language, !lang.isEmpty {
                HStack {
                    Text(lang).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.88))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled).padding(10)
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.93))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if message.status == .interrupted {
                Label(L.chatInterrupted, systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(.orange)
            }
            if isLastAssistant, let onRegenerate, message.status == .complete {
                Button(action: onRegenerate) {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Regenerate this response")
                .opacity(hover ? 1.0 : 0.7)
            }
            if !message.content.isEmpty, message.status != .streaming {
                Button(action: copy) {
                    Text(showCopied ? "Copied" : "Copy")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(showCopied ? .green : copyHover ? .blue : .secondary)
                }
                .buttonStyle(.borderless).onHover { copyHover = $0 }
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

    private var bubbleBackground: Color {
        switch message.role {
        case .user: Color.accentColor
        case .assistant: colorScheme == .dark ? Color(white: 0.18) : Color(white: 0.93)
        case .system: Color.orange.opacity(0.12)
        }
    }

    nonisolated static func == (l: Self, r: Self) -> Bool {
        l.message == r.message && l.isLastAssistant == r.isLastAssistant
    }
}
