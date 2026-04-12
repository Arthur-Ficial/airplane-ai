import Foundation
import Testing
@testable import AirplaneAI

@Suite("BackupStore")
struct BackupStoreTests {
    @Test func pruneKeepsOnlyLastN() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BackupStore(directory: dir, maxSnapshots: 3)

        for i in 0..<5 {
            try store.write([Conversation(title: "t\(i)")])
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms so creation dates differ
        }

        let items = try store.listSnapshots()
        #expect(items.count == 3)
    }

    @Test func emptyDirectoryReturnsNil() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = BackupStore(directory: dir)
        #expect(try store.readLatest() == nil)
    }
}
