import Foundation
import SwiftData
import Testing
@testable import AirplaneAI

@Suite("Schema migration V1→V2")
struct AttachmentMigrationTests {
    @Test func migrationPlanIncludesV2() {
        let schemas = AppMigrationPlan.schemas
        let names = schemas.map { String(describing: $0) }
        #expect(names.contains { $0.contains("AppSchemaV2") })
    }

    @Test func v1ConversationOpensAfterMigration() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let storeURL = tmp.appendingPathComponent("migrate.sqlite")
        let backupDir = tmp.appendingPathComponent("backups")
        let store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)

        // Save a v1-style conversation (no attachments).
        var c = Conversation(title: "Pre-migration")
        c.messages = [ChatMessage(role: .user, content: "old message")]
        try await store.save(c)

        // Reload — migration must have run; attachments default to [].
        let loaded = try await store.conversation(id: c.id)
        #expect(loaded != nil)
        #expect(loaded?.messages.first?.attachments.isEmpty == true)
    }

    @Test func attachmentsRoundTripThroughStore() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let storeURL = tmp.appendingPathComponent("attach.sqlite")
        let backupDir = tmp.appendingPathComponent("backups")
        let store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)

        var c = Conversation(title: "With attachments")
        c.messages = [ChatMessage(
            role: .user,
            content: "See attached",
            attachments: [.document(text: "hello", filename: "hi.txt", fileType: "txt")]
        )]
        try await store.save(c)

        let loaded = try await store.conversation(id: c.id)
        #expect(loaded?.messages.first?.attachments.count == 1)
    }
}
