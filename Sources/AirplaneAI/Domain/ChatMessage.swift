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

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        status: MessageStatus = .complete,
        stopReason: StopReason? = nil,
        tokenCount: Int? = nil,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.stopReason = stopReason
        self.tokenCount = tokenCount
        self.durationMs = durationMs
    }
}
