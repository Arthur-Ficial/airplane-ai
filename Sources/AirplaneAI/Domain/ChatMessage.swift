import Foundation

public enum MessageRole: String, Codable, Sendable {
    case system, user, assistant
}

public enum MessageStatus: String, Codable, Sendable {
    case complete, streaming, interrupted, failed
}

public struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public let createdAt: Date
    public var status: MessageStatus
    public var stopReason: StopReason?
    public var tokenCount: Int?         // set on assistant messages after streaming
    public var durationMs: Int?         // wall-clock ms from first to last token
    public var attachments: [Attachment]

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        status: MessageStatus = .complete,
        stopReason: StopReason? = nil,
        tokenCount: Int? = nil,
        durationMs: Int? = nil,
        attachments: [Attachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.stopReason = stopReason
        self.tokenCount = tokenCount
        self.durationMs = durationMs
        self.attachments = attachments
    }

    /// Content with attachment text prepended — what the model actually sees.
    public var materializedContent: String {
        guard !attachments.isEmpty else { return content }
        var blocks: [String] = []
        for a in attachments {
            switch a {
            case .image(_, let text):
                blocks.append("CONTEXT: image\n\(text)")
            case .document(let text, let name, _):
                blocks.append("CONTEXT: document (\(name))\n\(text)")
            case .audio(let transcript):
                blocks.append("CONTEXT: speech transcript\n\(transcript)")
            }
        }
        blocks.append(content)
        return blocks.joined(separator: "\n\n")
    }

    /// Rough token estimate including attachment text (~4 chars/token).
    public var estimatedTotalTokens: Int {
        max(1, materializedContent.count / 4)
    }
}
