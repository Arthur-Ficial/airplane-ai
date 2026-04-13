import Foundation
import SwiftData

public enum AppMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [AppSchemaV1.self, AppSchemaV2.self] }
    public static var stages: [MigrationStage] { [] }
    // V1→V2 migration is handled by SwiftData automatically (lightweight: new nullable column).
    // Explicit stage removed because it deadlocks ModelContainer init on MainActor.
}
