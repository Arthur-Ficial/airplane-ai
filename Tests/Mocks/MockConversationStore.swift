import Foundation
@testable import AirplaneAI

final class MockConversationStore: ConversationStore, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [UUID: Conversation] = [:]
    private var snapshots: [[Conversation]] = []
    var injectedFailure: Error?

    func allConversations() async throws -> [Conversation] {
        if let err = injectedFailure { throw err }
        return lock.withLock { Array(store.values).sorted { $0.updatedAt > $1.updatedAt } }
    }

    func conversation(id: UUID) async throws -> Conversation? {
        if let err = injectedFailure { throw err }
        return lock.withLock { store[id] }
    }

    func save(_ conversation: Conversation) async throws {
        if let err = injectedFailure { throw err }
        lock.withLock { store[conversation.id] = conversation }
    }

    func delete(id: UUID) async throws {
        if let err = injectedFailure { throw err }
        lock.withLock { _ = store.removeValue(forKey: id) }
    }

    func saveBackupSnapshot(_ conversations: [Conversation]) async throws {
        lock.withLock {
            snapshots.append(conversations)
            if snapshots.count > 10 { snapshots.removeFirst(snapshots.count - 10) }
        }
    }

    func loadLatestBackupSnapshot() async throws -> [Conversation]? {
        lock.withLock { snapshots.last }
    }
}
