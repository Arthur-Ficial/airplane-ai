import SwiftUI
import AppKit

struct ChatView: View {
    let state: AppState
    let controller: ChatController
    @State private var draft: String = ""
    @State private var isFollowingTail = true
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if (state.activeConversation?.messages ?? []).isEmpty {
                WelcomeView()
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
        .onChange(of: state.activeConversationID) { _, _ in
            isFollowingTail = true
            composerFocused = true
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Metrics.Padding.large) {
                    ForEach(state.activeConversation?.messages ?? []) { msg in
                        MessageBubble(message: msg).equatable().id(msg.id)
                    }
                }
                .padding(.vertical, 20)
                // Sentinel outside the VStack so scrollTo("bottom") reaches the true last pixel.
                Color.clear
                    .frame(height: 1).id("bottom")
                    .onAppear { isFollowingTail = true }
                    .onDisappear { isFollowingTail = false }
            }
            .onChange(of: (state.activeConversation?.messages ?? []).count) { old, new in
                guard new > old else { return }
                let userJustSent = state.activeConversation?.messages.last?.role == .user
                guard isFollowingTail || new <= 2 || userJustSent else { return }
                withAnimation(.easeOut(duration: Metrics.Duration.quickAnimation)) {
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
        Task {
            await controller.send(text)
            composerFocused = true
        }
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
            HStack(alignment: .bottom, spacing: Metrics.Padding.small) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused(focused)
                    .lineLimit(1...6)
                    .onSubmit {
                        state.chatState == .generating ? onStop() : onSubmit()
                    }
                    .onKeyPress(.escape) {
                        if state.chatState == .generating { onStop(); return .handled }
                        if !draft.isEmpty { draft = ""; return .handled }
                        return .ignored
                    }
                SendButton(
                    generating: state.chatState == .generating,
                    canSend: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onTap: state.chatState == .generating ? onStop : onSubmit
                )
                .padding(.bottom, 2) // align with rounded-border TextField baseline
            }
            .padding(.horizontal, Metrics.Padding.regular)
            .padding(.vertical, Metrics.Padding.small)
        }
        .onAppear { focused.wrappedValue = true }
    }

    private var placeholder: String {
        state.chatState == .generating ? L.chatGenerating : "Type a message, press Enter to send…"
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: Metrics.Padding.large) {
            Spacer()
            AirplaneGlyph(size: Metrics.Size.airplaneGlyphLarge)
            Text("Airplane AI").font(.title.weight(.semibold))
            Text(L.tagline).font(.title3).foregroundStyle(.secondary)
            Text("Press ⌘N for a new chat").font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
