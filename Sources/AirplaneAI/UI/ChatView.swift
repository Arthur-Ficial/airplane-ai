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
                    let messages = state.activeConversation?.messages ?? []
                    let lastAssistantID = messages.last(where: { $0.role == .assistant })?.id
                    ForEach(messages) { msg in
                        MessageBubble(
                            message: msg,
                            isLastAssistant: msg.id == lastAssistantID,
                            onRegenerate: msg.id == lastAssistantID ? { Task { await controller.regenerateLastAssistant() } } : nil,
                            onDelete: { controller.deleteMessage(msg.id) }
                        )
                        .equatable()
                        .id(msg.id)
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

    @State private var composerHeight: CGFloat = Metrics.Composer.minHeight

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: Metrics.Composer.gap) {
                TextField(placeholder, text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .focused(focused)
                    .lineLimit(Metrics.Composer.minLines...Metrics.Composer.maxLines)
                    .frame(minHeight: composerHeight, maxHeight: composerHeight)
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
                    awaitingFirstToken: state.awaitingFirstToken,
                    onTap: state.chatState == .generating ? onStop : onSubmit
                )
                .padding(.bottom, 2)
            }
            .padding(.horizontal, Metrics.Composer.horizontalPadding)
            .padding(.vertical, Metrics.Composer.verticalPadding)
            .overlay(resizeHandle, alignment: .topTrailing)
        }
        .onAppear { focused.wrappedValue = true }
    }

    // Small grab handle on top-right of the composer strip. Drag up to grow, down to shrink.
    private var resizeHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.caption2).foregroundStyle(.tertiary)
            .padding(.top, 2).padding(.trailing, 6)
            .frame(width: 24, height: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { drag in
                        let proposed = composerHeight - drag.translation.height
                        composerHeight = min(Metrics.Composer.maxHeight, max(Metrics.Composer.minHeight, proposed))
                    }
            )
            .help("Drag to resize")
            .accessibilityLabel("Resize composer")
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
