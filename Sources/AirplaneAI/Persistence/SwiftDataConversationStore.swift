import Foundation
import SwiftData

// Actor-isolated store. Owns its ModelContext.
public actor SwiftDataConversationStore: ConversationStore {
    private let container: ModelContainer
    private let context: ModelContext
    private let backupStore: BackupStore

    public init(storeURL: URL, backupDirectory: URL) throws {
        let schema = Schema(versionedSchema: AppSchemaV2.self)
        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        self.container = try ModelContainer(for: schema, migrationPlan: AppMigrationPlan.self, configurations: [config])
        self.context = ModelContext(container)
        self.backupStore = BackupStore(directory: backupDirectory)
    }

    public init(container: ModelContainer, backupDirectory: URL) {
        self.container = container
        self.context = ModelContext(container)
        self.backupStore = BackupStore(directory: backupDirectory)
    }

    public func allConversations() async throws -> [Conversation] {
        let descriptor = FetchDescriptor<StoredConversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        let rows = try context.fetch(descriptor)
        return rows.map(StoreMapper.toDomain)
    }

    public func conversation(id: UUID) async throws -> Conversation? {
        guard let sc = try findStored(id: id) else { return nil }
        return StoreMapper.toDomain(sc)
    }

    public func save(_ conversation: Conversation) async throws {
        if let sc = try findStored(id: conversation.id) {
            StoreMapper.update(sc, from: conversation)
        } else {
            let sc = StoreMapper.makeStored(from: conversation)
            context.insert(sc)
        }
        try context.save()
    }

    public func delete(id: UUID) async throws {
        guard let sc = try findStored(id: id) else { return }
        context.delete(sc)
        try context.save()
    }

    public func saveBackupSnapshot(_ conversations: [Conversation]) async throws {
        try backupStore.write(conversations)
    }

    public func loadLatestBackupSnapshot() async throws -> [Conversation]? {
        try backupStore.readLatest()
    }

    private func findStored(id: UUID) throws -> StoredConversation? {
        let descriptor = FetchDescriptor<StoredConversation>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
}
