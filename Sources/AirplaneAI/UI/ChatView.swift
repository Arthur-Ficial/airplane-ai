import SwiftUI
import AppKit

// Ported from apfel-chat's ChatView (proven design). Key differences:
// - No speech/image input in v1 (spec §1: text-only)
// - Uses our AppState + ChatController instead of ChatViewModel
struct ChatView: View {
    let state: AppState
    let controller: ChatController
    @State private var draft: String = ""
    @State private var isFollowingTail = true
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if (state.activeConversation?.messages ?? []).isEmpty {
                emptyState
            } else {
                messageList
            }
            InputBar(
                state: state,
                draft: $draft,
                focused: $composerFocused,
                onSubmit: submit,
                onStop: stop
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("Start a conversation")
                .font(.title2).fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("Private AI on your Mac")
                .font(.subheadline).foregroundStyle(.tertiary)
            Text("Press ⌘N for new chat")
                .font(.caption).foregroundStyle(.quaternary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(state.activeConversation?.messages ?? []) { msg in
                        MessageBubble(message: msg).equatable().id(msg.id)
                    }
                }
                .padding(.vertical, 20)

                Color.clear
                    .frame(height: 1).id("bottom")
                    .onAppear { isFollowingTail = true }
                    .onDisappear { isFollowingTail = false }
            }
            .onChange(of: (state.activeConversation?.messages ?? []).count) { old, new in
                guard new > old else { return }
                let userJustSent = state.activeConversation?.messages.last?.role == .user
                guard isFollowingTail || new <= 2 || userJustSent else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: state.activeConversation?.messages.last?.content) { _, _ in
                guard isFollowingTail else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await controller.send(text) }
    }

    private func stop() { controller.stop() }
}

struct InputBar: View {
    let state: AppState
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: 10) {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .focused(focused)
                    .frame(minHeight: 36)
                    .onSubmit {
                        state.chatState == .generating ? onStop() : onSubmit()
                    }
                SendButton(
                    generating: state.chatState == .generating,
                    canSend: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onTap: state.chatState == .generating ? onStop : onSubmit
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .onAppear { focused.wrappedValue = true }
    }

    private var placeholder: String {
        state.chatState == .generating ? L.chatGenerating : "Type a message, press Enter to send…"
    }
}
