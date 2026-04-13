import Foundation
import SwiftData

// V2 adds attachments (JSON blob) to stored messages.
public enum AppSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [StoredConversation.self, StoredMessage.self] }
}
