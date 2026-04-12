import Foundation
import SwiftData

// Migration plan is established from v1.0 — future versions add stages here.
public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
