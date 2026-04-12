import Foundation
import SwiftData
import Testing
@testable import AirplaneAI

@Suite("AppMigrationPlan")
struct MigrationPlanTests {
    @Test func planIncludesV1Schema() {
        let schemas = AppMigrationPlan.schemas
        #expect(!schemas.isEmpty)
        let versions = schemas.map { String(describing: $0) }
        #expect(versions.contains { $0.contains("AppSchemaV1") })
    }

    @Test func stagesEmptyForSingleVersion() {
        #expect(AppMigrationPlan.stages.isEmpty, "No migration stages expected while only V1 exists")
    }

    @Test func v1StoreOpensAndPersists() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let storeURL = tmp.appendingPathComponent("v1.sqlite")
        let backupDir = tmp.appendingPathComponent("backups")

        let store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)
        let c = Conversation(title: "V1 fixture")
        try await store.save(c)
        let loaded = try await store.conversation(id: c.id)
        #expect(loaded?.title == "V1 fixture")
    }
}
