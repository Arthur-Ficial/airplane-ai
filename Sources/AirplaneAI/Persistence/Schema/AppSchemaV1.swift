import Foundation
import SwiftData

// SSOT: the only place that describes the v1 persistent shape.
public enum AppSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [StoredConversation.self, StoredMessage.self] }
}

@Model
public final class StoredConversation {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \StoredMessage.conversation)
    public var messages: [StoredMessage] = []

    public init(id: UUID, title: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class StoredMessage {
    @Attribute(.unique) public var id: UUID
    public var role: String
    public var content: String
    public var createdAt: Date
    public var status: String
    public var stopReason: String?
    public var attachmentsJSON: Data?
    public var conversation: StoredConversation?

    public init(id: UUID, role: String, content: String, createdAt: Date, status: String, stopReason: String? = nil, attachmentsJSON: Data? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.stopReason = stopReason
        self.attachmentsJSON = attachmentsJSON
    }
}
