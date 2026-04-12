import Foundation
import SwiftData
import Testing
@testable import AirplaneAI

@Suite("SwiftDataConversationStore")
struct SwiftDataStoreTests {
    private func makeStore() throws -> (SwiftDataConversationStore, URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let storeURL = tmp.appendingPathComponent("store.sqlite")
        let backupDir = tmp.appendingPathComponent("backups")
        let store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)
        return (store, tmp)
    }

    @Test func roundTripSingleConversation() async throws {
        let (store, tmp) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        var c = Conversation(title: "Hello")
        c.messages = [
            ChatMessage(role: .user, content: "Hi"),
            ChatMessage(role: .assistant, content: "There", status: .complete),
        ]
        try await store.save(c)

        let loaded = try await store.conversation(id: c.id)
        #expect(loaded?.title == "Hello")
        #expect(loaded?.messages.count == 2)
    }

    @Test func updatesExistingConversation() async throws {
        let (store, tmp) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        var c = Conversation(title: "v1")
        try await store.save(c)
        c.title = "v2"
        c.updatedAt = .now
        try await store.save(c)

        let loaded = try await store.conversation(id: c.id)
        #expect(loaded?.title == "v2")
    }

    @Test func deletes() async throws {
        let (store, tmp) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let c = Conversation(title: "toDelete")
        try await store.save(c)
        try await store.delete(id: c.id)
        let loaded = try await store.conversation(id: c.id)
        #expect(loaded == nil)
    }

    @Test func listsSortedByUpdatedAtDescending() async throws {
        let (store, tmp) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tmp) }

        var a = Conversation(title: "A"); a.updatedAt = Date(timeIntervalSince1970: 100)
        var b = Conversation(title: "B"); b.updatedAt = Date(timeIntervalSince1970: 200)
        try await store.save(a); try await store.save(b)
        let list = try await store.allConversations()
        #expect(list.first?.title == "B")
    }

    @Test func backupSnapshotRoundTrip() async throws {
        let (store, tmp) = try makeStore()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let convos = [Conversation(title: "X"), Conversation(title: "Y")]
        try await store.saveBackupSnapshot(convos)
        let loaded = try await store.loadLatestBackupSnapshot()
        #expect(loaded?.count == 2)
        #expect(Set(loaded?.map(\.title) ?? []) == Set(["X", "Y"]))
    }
}
