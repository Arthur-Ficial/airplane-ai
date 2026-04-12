import SwiftUI

struct RootWindow: View {
    let wiring: AppWiring?
    let bootError: String?

    var body: some View {
        Group {
            if let wiring { main(wiring: wiring) }
            else if let err = bootError { errorView(text: err) }
            else { BootScreen(state: AppState()) }
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    @ViewBuilder
    private func main(wiring: AppWiring) -> some View {
        // Show boot screen until the model is ready (or a hard error occurs).
        switch wiring.state.modelState {
        case .ready:
            mainLayout(wiring: wiring)
        case .blockedInsufficientResources(let e):
            InsufficientResourcesView(error: e)
        case .modelCorrupt, .modelMissing:
            ModelCorruptView()
        case .migrationFailed:
            MigrationFailureView()
        default:
            BootScreen(state: wiring.state)
        }
    }

    private func mainLayout(wiring: AppWiring) -> some View {
        let hasTitle = wiring.state.activeConversation?.title.isEmpty == false
        let title = hasTitle ? wiring.state.activeConversation!.title : "Airplane AI"
        return NavigationSplitView {
            ConversationListView(state: wiring.state, controller: wiring.conversationController)
                .frame(minWidth: 240)
        } detail: {
            ChatView(state: wiring.state, controller: wiring.chatController)
                .navigationTitle(title)
                .navigationSubtitle(wiring.state.modelState == .ready ? "● Ready" : "○ Loading…")
        }
    }

    private func errorView(text: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundStyle(.orange)
            Text("Startup failed").font(.title2.weight(.semibold))
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: 520)
    }
}
