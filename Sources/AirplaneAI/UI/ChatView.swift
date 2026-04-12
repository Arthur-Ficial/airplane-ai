import SwiftUI

struct ChatView: View {
    let state: AppState
    let controller: ChatController
    @State private var draft: String = ""
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(state.activeConversation?.messages ?? []) { msg in
                            MessageBubble(message: msg).id(msg.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: state.activeConversation?.messages.last?.content) { _, _ in
                    if autoScroll, let last = state.activeConversation?.messages.last {
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            Divider()
            composer
        }
    }

    private var composer: some View {
        let generating = state.chatState == .generating
        let buttonLabel: String = generating ? String(localized: "action.stop") : String(localized: "action.send")
        let icon = generating ? "stop.circle.fill" : "paperplane.fill"
        let action: () -> Void = generating ? stop : submit
        return HStack(alignment: .bottom, spacing: 8) {
            ComposerView(
                text: $draft,
                isGenerating: generating,
                onSubmit: submit,
                onStop: stop
            )
            .frame(minHeight: 44, maxHeight: 120)

            Button(action: action) {
                Image(systemName: icon).font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(buttonLabel)
        }
        .padding(12)
    }

    private func submit() {
        let text = draft
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        draft = ""
        Task { await controller.send(text) }
    }

    private func stop() { controller.stop() }
}
