import Foundation
import SwiftUI

// Ported from apfel-chat. Parses markdown into text+code blocks, caches
// AttributedString renders so streaming doesn't recompute on every tick.
enum MarkdownRenderer {
    struct Block: Identifiable, Sendable {
        enum Kind: String, Sendable { case text, code }
        let kind: Kind
        let content: String
        let language: String?
        let rendered: AttributedString?
        let id: String
    }

    struct Render {
        let isJSON: Bool
        let prettyJSON: String
        let blocks: [Block]
    }

    @MainActor private static var cache: [String: Render] = [:]
    @MainActor private static var order: [String] = []
    private static let cacheLimit = 300

    @MainActor
    static func cached(_ content: String) -> Render {
        if let hit = cache[content] { touch(content); return hit }
        let result = compute(content)
        cache[content] = result
        touch(content)
        evictIfNeeded()
        return result
    }

    private static func compute(_ content: String) -> Render {
        if isJSON(content) { return Render(isJSON: true, prettyJSON: prettyJSON(content), blocks: []) }
        return Render(isJSON: false, prettyJSON: "", blocks: parse(content))
    }

    private static func parse(_ md: String) -> [Block] {
        var blocks: [Block] = []
        var text = ""
        var code = ""
        var lang: String?
        var inCode = false
        var idx = 0

        for raw in md.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    blocks.append(Block(kind: .code, content: code.trimmingCharacters(in: .newlines), language: lang, rendered: nil,
                                        id: blockID(.code, idx, code, lang)))
                    idx += 1; code = ""; lang = nil; inCode = false
                } else {
                    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty {
                        blocks.append(Block(kind: .text, content: t, language: nil, rendered: render(t),
                                            id: blockID(.text, idx, t, nil)))
                        idx += 1
                    }
                    text = ""
                    let l = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    lang = l.isEmpty ? nil : l
                    inCode = true
                }
            } else if inCode {
                if !code.isEmpty { code += "\n" }
                code += raw
            } else {
                if !text.isEmpty { text += "\n" }
                text += raw
            }
        }
        if inCode, !code.isEmpty {
            blocks.append(Block(kind: .code, content: code, language: lang, rendered: nil, id: blockID(.code, idx, code, lang)))
        }
        let tail = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            blocks.append(Block(kind: .text, content: tail, language: nil, rendered: render(tail), id: blockID(.text, idx, tail, nil)))
        }
        return blocks
    }

    static func render(_ md: String) -> AttributedString {
        (try? AttributedString(markdown: md, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(md)
    }

    static func isJSON(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("{") || t.hasPrefix("[") else { return false }
        guard let data = t.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    static func prettyJSON(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return text }
        return str
    }

    @MainActor private static func touch(_ k: String) {
        order.removeAll { $0 == k }; order.append(k)
    }
    @MainActor private static func evictIfNeeded() {
        while order.count > cacheLimit { let g = order.removeFirst(); cache.removeValue(forKey: g) }
    }
    private static func blockID(_ kind: Block.Kind, _ i: Int, _ c: String, _ l: String?) -> String {
        "\(kind.rawValue)-\(i)-\(l ?? "plain")-\(c.hashValue)"
    }
}
