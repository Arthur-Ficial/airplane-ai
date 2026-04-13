import Foundation
import SwiftData

public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // V1→V2: adds attachmentsJSON column (nullable, defaults nil = empty []).
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: AppSchemaV1.self,
        toVersion: AppSchemaV2.self
    )
}
