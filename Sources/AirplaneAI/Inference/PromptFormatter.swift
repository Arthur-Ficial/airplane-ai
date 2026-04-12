import Foundation
import CLlama

// Prefer the model's own chat template via llama_chat_apply_template.
// Fallback: Gemma-style <start_of_turn>/<end_of_turn> format (single tested formatter).
public struct PromptFormatter: Sendable {
    public init() {}

    public func format(systemPrompt: String, messages: [ChatMessage], model: OpaquePointer?) -> String {
        // Build the llama_chat_message array.
        var allMessages: [ChatMessage] = []
        if !systemPrompt.isEmpty {
            allMessages.append(ChatMessage(role: .system, content: systemPrompt))
        }
        allMessages.append(contentsOf: messages)

        // Try llama_chat_apply_template (uses model's metadata template by default).
        if let model, let applied = applyTemplate(messages: allMessages, model: model) {
            return applied
        }
        return fallbackGemma(messages: allMessages)
    }

    private func applyTemplate(messages: [ChatMessage], model: OpaquePointer) -> String? {
        // Build C-owned roles/contents.
        let roleStrings = messages.map { Self.roleString($0.role) }
        let contentStrings = messages.map { $0.content }

        // Allocate llama_chat_message array.
        var chatMsgs = [llama_chat_message]()
        chatMsgs.reserveCapacity(messages.count)
        var bufs: [(UnsafeMutablePointer<CChar>, UnsafeMutablePointer<CChar>)] = []
        defer { for (r, c) in bufs { r.deallocate(); c.deallocate() } }

        for i in 0..<messages.count {
            let r = strdup_local(roleStrings[i])
            let c = strdup_local(contentStrings[i])
            bufs.append((r, c))
            chatMsgs.append(llama_chat_message(role: UnsafePointer(r), content: UnsafePointer(c)))
        }

        // First call with nil buffer to get required length.
        let template: UnsafePointer<CChar>? = nil // use model-stored template
        var out = [CChar](repeating: 0, count: 8192)
        let written = chatMsgs.withUnsafeBufferPointer { mbuf -> Int32 in
            llama_chat_apply_template(template, mbuf.baseAddress, mbuf.count, true, &out, Int32(out.count))
        }
        if written <= 0 { return nil }
        if Int(written) > out.count {
            out = [CChar](repeating: 0, count: Int(written) + 1)
            let w2 = chatMsgs.withUnsafeBufferPointer { mbuf -> Int32 in
                llama_chat_apply_template(template, mbuf.baseAddress, mbuf.count, true, &out, Int32(out.count))
            }
            if w2 <= 0 { return nil }
        }
        return String(cString: out)
    }

    private func fallbackGemma(messages: [ChatMessage]) -> String {
        var out = ""
        for m in messages {
            out += "<start_of_turn>\(Self.roleString(m.role))\n\(m.content)<end_of_turn>\n"
        }
        out += "<start_of_turn>model\n"
        return out
    }

    static func roleString(_ r: MessageRole) -> String {
        switch r {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "model"
        }
    }
}

private func strdup_local(_ s: String) -> UnsafeMutablePointer<CChar> {
    let bytes = s.utf8CString
    let buf = UnsafeMutablePointer<CChar>.allocate(capacity: bytes.count)
    bytes.withUnsafeBufferPointer { src in
        buf.update(from: src.baseAddress!, count: bytes.count)
    }
    return buf
}
