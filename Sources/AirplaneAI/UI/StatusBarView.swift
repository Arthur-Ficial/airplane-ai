import SwiftUI

struct StatusBarView: View {
    let state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }

    private var color: Color {
        switch state.modelState {
        case .ready: .green
        case .cold, .unloading: .gray
        case .verifyingModel, .loadingModel, .warmingModel: .yellow
        default: .red
        }
    }

    private var label: String {
        switch state.modelState {
        case .cold: "—"
        case .verifyingModel: String(localized: "model.verifying")
        case .loadingModel: String(localized: "model.loading")
        case .warmingModel: String(localized: "model.warming")
        case .ready: String(localized: "model.ready")
        case .unloading: "…"
        case .modelMissing: "Model missing"
        case .modelCorrupt: String(localized: "model.corrupt.title")
        case .blockedInsufficientResources(let e): e.errorDescription ?? "Insufficient resources"
        case .loadFailed(let s): "Load failed: \(s)"
        case .migrationFailed: "Migration failed"
        }
    }
}
