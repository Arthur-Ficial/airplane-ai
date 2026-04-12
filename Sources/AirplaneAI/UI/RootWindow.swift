import SwiftUI

struct RootWindow: View {
    let wiring: AppWiring?
    let bootError: String?
    @AppStorage("airplane.appearance") private var appearance: String = "system"

    var body: some View {
        Group {
            if let wiring { main(wiring: wiring) }
            else if let err = bootError { errorView(text: err) }
            else { BootScreen(state: AppState()) }
        }
        .frame(minWidth: 960, minHeight: 640)
        .preferredColorScheme(preferredScheme)
    }

    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": .light
        case "dark": .dark
        default: nil
        }
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
        let rawTitle = wiring.state.activeConversation?.title ?? ""
        let stripped = OutputSanitizer.stripLeakingMarkers(rawTitle).0
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = stripped.isEmpty ? "Airplane AI" : stripped
        let dot = dotColor(for: wiring.state.modelState)
        // Inline SF Symbol tinted at the symbol level — Text concatenation in
        // navigationTitle preserves the tint when the Image has renderingMode(.template).
        let dotText = Text(Image(systemName: "circle.fill")).foregroundColor(dot)
        let titleText = dotText + Text("  ") + Text(title)
        return NavigationSplitView {
            ConversationListView(state: wiring.state, controller: wiring.conversationController)
                .frame(minWidth: 240)
        } detail: {
            ChatView(state: wiring.state, controller: wiring.chatController)
                .navigationTitle(titleText)
        }
    }

    private func dotColor(for s: ModelLifecycle) -> Color {
        switch s {
        case .ready: .green
        case .blockedInsufficientResources, .loadFailed, .modelCorrupt, .modelMissing, .migrationFailed: .red
        default: .blue
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
