import SwiftUI

struct InsufficientResourcesView: View {
    let error: AppError
    var body: some View { errorLayout(title: String(localized: "memory.title"), body: error.errorDescription ?? "") }
}

struct ModelCorruptView: View {
    var body: some View {
        errorLayout(title: String(localized: "model.corrupt.title"), body: String(localized: "model.corrupt.body"))
    }
}

struct MigrationFailureView: View {
    var body: some View {
        errorLayout(title: "Data migration failed", body: "Please reinstall Airplane AI.")
    }
}

@ViewBuilder
private func errorLayout(title: String, body: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 36)).foregroundStyle(.orange)
        Text(title).font(.title2.weight(.semibold))
        Text(body).multilineTextAlignment(.center).foregroundStyle(.secondary)
    }
    .padding(40)
    .frame(maxWidth: 520)
}
