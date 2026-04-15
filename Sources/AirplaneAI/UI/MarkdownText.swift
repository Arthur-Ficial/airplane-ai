import SwiftUI

// Minimal local markdown renderer. Spec §14: paragraphs, emphasis, inline code,
// fenced code blocks, bullet/numbered lists. NO HTML. NO remote images. NO WebKit.
struct MarkdownText: View {
    let text: String

    var body: some View {
        let blocks = parseBlocks(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks.indices, id: \.self) { idx in
                render(blocks[idx])
            }
        }
    }

    @ViewBuilder
    private func render(_ block: Block) -> some View {
        switch block {
        case .paragraph(let raw):
            Text(inline(raw))
                .textSelection(.enabled)
        case .code(let body, let lang):
            CodeBlockView(code: body, language: lang)
        case .list(let items, let ordered):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(items.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(ordered ? "\(i + 1)." : "•").foregroundStyle(.secondary)
                        Text(inline(items[i])).textSelection(.enabled)
                    }
                }
            }
        }
    }

    // AttributedString via SwiftUI's native Markdown for inline emphasis/inline-code.
    private func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
    }

    enum Block: Equatable {
        case paragraph(String)
        case code(String, String?)
        case list([String], ordered: Bool)
    }

    func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).map(String.init)
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].hasPrefix("```") {
                    body.append(lines[i]); i += 1
                }
                if i < lines.count { i += 1 } // consume closing fence
                blocks.append(.code(body.joined(separator: "\n"), lang.isEmpty ? nil : lang))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                var items: [String] = []
                while i < lines.count, lines[i].hasPrefix("- ") || lines[i].hasPrefix("* ") {
                    items.append(String(lines[i].dropFirst(2))); i += 1
                }
                blocks.append(.list(items, ordered: false))
            } else if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                var items: [String] = []
                while i < lines.count, let m = lines[i].range(of: #"^\d+\.\s"#, options: .regularExpression) {
                    items.append(String(lines[i][m.upperBound...])); i += 1
                    _ = match
                }
                blocks.append(.list(items, ordered: true))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
            } else {
                var para = [line]
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).isEmpty,
                      !lines[i].hasPrefix("```"), !lines[i].hasPrefix("- "), !lines[i].hasPrefix("* "),
                      lines[i].range(of: #"^\d+\.\s"#, options: .regularExpression) == nil {
                    para.append(lines[i]); i += 1
                }
                blocks.append(.paragraph(para.joined(separator: "\n")))
            }
        }
        return blocks
    }
}

struct CodeBlockView: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language, !lang.isEmpty {
                Text(lang).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.top, 6)
            }
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
