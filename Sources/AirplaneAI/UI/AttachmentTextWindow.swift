import SwiftUI
import AppKit

/// Opens a proper macOS window showing the extracted text of an attachment.
/// Read-only, monospace, line numbers, token count, light/dark aware.
@MainActor
enum AttachmentTextWindow {
    static func open(title: String, text: String, tokenCount: Int? = nil) {
        let view = AttachmentTextView(title: title, text: text, tokenCount: tokenCount)
        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 540),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
    }
}

private struct AttachmentTextView: View {
    let title: String
    let text: String
    let tokenCount: Int?
    @Environment(\.colorScheme) private var scheme

    private var lines: [String] { text.components(separatedBy: .newlines) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            numberedTextContent
        }
        .frame(minWidth: 500, minHeight: 350)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Text(title).font(.headline).lineLimit(1)
            Spacer()
            Text("READ ONLY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(scheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                )
            if let tok = tokenCount {
                Text("\(tok) tok")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.secondary)
            }
            Text("\(lines.count) lines")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.97))
    }

    private var numberedTextContent: some View {
        let gutterWidth = gutterWidthForLineCount(lines.count)
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, _ in
                        Text("\(idx + 1)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(height: 16, alignment: .trailing)
                    }
                }
                .frame(width: gutterWidth)
                .padding(.leading, 6)
                .padding(.trailing, 4)
                .padding(.top, 6)
                .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.95))

                Rectangle()
                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                    .frame(width: 1)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(height: 16, alignment: .leading)
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
        }
        .background(scheme == .dark ? Color(nsColor: .textBackgroundColor) : .white)
    }

    private func gutterWidthForLineCount(_ count: Int) -> CGFloat {
        let digits = max(2, String(count).count)
        return CGFloat(digits) * 8 + 4
    }
}
