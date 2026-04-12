import SwiftUI

struct RootWindow: View {
    let wiring: AppWiring?
    let bootError: String?

    var body: some View {
        if let wiring { main(wiring: wiring) }
        else if let err = bootError { error(text: err) }
        else { ProgressView().frame(minWidth: 520, minHeight: 360) }
    }

    @ViewBuilder
    private func main(wiring: AppWiring) -> some View {
        NavigationSplitView {
            ConversationListView(state: wiring.state, controller: wiring.conversationController)
                .frame(minWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                StatusBarView(state: wiring.state)
                detail(wiring: wiring)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    @ViewBuilder
    private func detail(wiring: AppWiring) -> some View {
        switch wiring.state.modelState {
        case .blockedInsufficientResources(let e):
            InsufficientResourcesView(error: e)
        case .modelCorrupt, .modelMissing:
            ModelCorruptView()
        case .migrationFailed:
            MigrationFailureView()
        default:
            ChatView(state: wiring.state, controller: wiring.chatController)
        }
    }

    private func error(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 36)).foregroundStyle(.orange)
            Text("Startup failed").font(.title2.weight(.semibold))
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(minWidth: 520, minHeight: 360)
    }
}
