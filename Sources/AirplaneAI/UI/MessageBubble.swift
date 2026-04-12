import SwiftUI
import AppKit

struct MessageBubble: View, Equatable {
    let message: ChatMessage
    var isLastAssistant: Bool = false
    var onRegenerate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onQuote: ((String) -> Void)? = nil
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
            if let onQuote {
                Button("Quote in reply") {
                    let quoted = OutputSanitizer.stripLeakingMarkers(message.content).0
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map { "> \($0)" }
                        .joined(separator: "\n")
                    onQuote(quoted + "\n\n")
                }
            }
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
            HStack {
                if let lang = block.language, !lang.isEmpty {
                    Text(lang).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { copyText(block.content) }) {
                    Label(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(showCopied ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Copy code")
                .accessibilityLabel("Copy code block")
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Palette.codeHeader(colorScheme))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled).padding(10)
            }
            .background(Palette.codeBackground(colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCopied = false }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            #if AIRPLANE_DEBUG
            if let tok = message.tokenCount {
                Text("\(tok) tok").font(.caption2.monospacedDigit()).foregroundStyle(.quaternary)
            }
            if let ms = message.durationMs {
                Text("\(ms) ms").font(.caption2.monospacedDigit()).foregroundStyle(.quaternary)
            }
            #endif
            if message.status == .interrupted {
                Label(L.chatInterrupted, systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(.orange)
            }
            if isLastAssistant, let onRegenerate, message.status == .complete {
                IconActionButton(
                    systemName: "arrow.clockwise",
                    help: "Regenerate this response",
                    action: onRegenerate
                )
            }
            if !message.content.isEmpty, message.status != .streaming {
                Button(action: copy) {
                    Text(showCopied ? "Copied" : "Copy")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(showCopied ? .green : copyHover ? Palette.accent : .secondary)
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
