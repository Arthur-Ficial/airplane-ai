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

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        status: MessageStatus = .complete,
        stopReason: StopReason? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.stopReason = stopReason
    }
}
