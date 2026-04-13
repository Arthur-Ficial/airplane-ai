import SwiftUI
import AppKit

/// Opens a proper macOS window showing the extracted text of an attachment.
/// Read-only, monospace, line numbers, light/dark aware.
@MainActor
enum AttachmentTextWindow {
    static func open(title: String, text: String) {
        let hostingView = NSHostingView(rootView: AttachmentTextView(title: title, text: text))
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
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text("READ ONLY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(scheme == .dark ? .white.opacity(0.5) : .black.opacity(0.4))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                )
            Text("\(lines.count) lines")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.97))
    }

    private var numberedTextContent: some View {
        let gutterWidth = gutterWidthForLineCount(lines.count)
        return ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top, spacing: 0) {
                // Line number gutter
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, _ in
                        Text("\(idx + 1)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(height: 18, alignment: .trailing)
                    }
                }
                .frame(width: gutterWidth)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.top, 12)
                .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.95))

                // Gutter separator
                Rectangle()
                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                    .frame(width: 1)

                // Text content
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(height: 18, alignment: .leading)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
                .padding(.top, 12)

                Spacer(minLength: 0)
            }
        }
        .background(scheme == .dark ? Color(nsColor: .textBackgroundColor) : .white)
    }

    private func gutterWidthForLineCount(_ count: Int) -> CGFloat {
        let digits = max(2, String(count).count)
        return CGFloat(digits) * 9 + 8
    }
}
