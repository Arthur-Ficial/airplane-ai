import Foundation

public protocol ConversationStore: Sendable {
    func allConversations() async throws -> [Conversation]
    func conversation(id: UUID) async throws -> Conversation?
    func save(_ conversation: Conversation) async throws
    func delete(id: UUID) async throws
    func saveBackupSnapshot(_ conversations: [Conversation]) async throws
    func loadLatestBackupSnapshot() async throws -> [Conversation]?
}
