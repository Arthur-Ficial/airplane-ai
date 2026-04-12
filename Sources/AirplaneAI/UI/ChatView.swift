import SwiftUI
import AppKit

struct ChatView: View {
    let state: AppState
    let controller: ChatController
    @State private var draft: String = ""
    @State private var isFollowingTail = true
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .overlay(alignment: .top) {
            if let err = state.lastError {
                Toast(message: err.errorDescription ?? "An error occurred.",
                      onDismiss: { state.lastError = nil })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: err) {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if state.lastError == err { state.lastError = nil }
                    }
            }
        }
        .animation(.easeInOut(duration: Metrics.Duration.standardAnimation), value: state.lastError)
        .onChange(of: state.activeConversationID) { _, _ in
            isFollowingTail = true
            composerFocused = true
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                messageScroll(proxy: proxy)
                if !isFollowingTail {
                    Button {
                        withAnimation(.easeOut(duration: Metrics.Duration.quickAnimation)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Palette.accent))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
                    .help("Scroll to latest")
                    .accessibilityLabel("Scroll to latest message")
                    .transition(.opacity)
                }
            }
        }
    }

    private func messageScroll(proxy: ScrollViewProxy) -> some View {
            ScrollView {
                LazyVStack(spacing: Metrics.Padding.large) {
                    let messages = state.activeConversation?.messages ?? []
                    let lastAssistantID = messages.last(where: { $0.role == .assistant })?.id
                    ForEach(messages) { msg in
                        MessageBubble(
                            message: msg,
                            isLastAssistant: msg.id == lastAssistantID,
                            onRegenerate: msg.id == lastAssistantID ? { Task { await controller.regenerateLastAssistant() } } : nil,
                            onDelete: { controller.deleteMessage(msg.id) },
                            onQuote: { quoted in
                                draft = quoted + draft
                                composerFocused = true
                            }
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
                if reduceMotion {
                    proxy.scrollTo("bottom", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: Metrics.Duration.quickAnimation)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: state.activeConversation?.messages.last?.content) { _, _ in
                guard isFollowingTail else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
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
    @AppStorage("airplane.sendWith") private var sendWith: String = "enter"

    @State private var composerHeight: CGFloat = Metrics.Composer.minHeight

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: Metrics.Composer.gap) {
                editor
                SendButton(
                    generating: state.chatState == .generating,
                    canSend: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    awaitingFirstToken: state.awaitingFirstToken,
                    onTap: state.chatState == .generating ? onStop : onSubmit
                )
                .padding(.bottom, 4)
            }
            .padding(.horizontal, Metrics.Composer.horizontalPadding)
            .padding(.vertical, Metrics.Composer.verticalPadding)
            .overlay(resizeHandle, alignment: .topTrailing)
            .overlay(alignment: .bottomTrailing) {
                if draft.count > 500 {
                    Text("\(draft.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 56)
                        .padding(.bottom, 2)
                }
            }
        }
        .onAppear { focused.wrappedValue = true }
    }

    // TextEditor honors explicit frames, unlike multi-line TextField. Placeholder
    // overlay on empty text.
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $draft)
                .font(.body)
                .focused(focused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(height: composerHeight)
                .onKeyPress(phases: .down) { press in
                    guard press.key == .return else { return .ignored }
                    // Setting: Enter vs Cmd+Enter as the send shortcut.
                    let cmdMode = sendWith == "cmd-enter"
                    let mods = press.modifiers
                    if cmdMode {
                        // Cmd+Enter sends, plain Enter = newline.
                        if !mods.contains(.command) { return .ignored }
                    } else {
                        // Enter sends, Shift+Enter = newline.
                        if mods.contains(.shift) { return .ignored }
                    }
                    if state.chatState == .generating { onStop(); return .handled }
                    onSubmit()
                    return .handled
                }
                .onKeyPress(.escape) {
                    if state.chatState == .generating { onStop(); return .handled }
                    if !draft.isEmpty { draft = ""; return .handled }
                    return .ignored
                }
            if draft.isEmpty {
                // Match TextEditor's outer padding (8) + its intrinsic
                // textContainerInset (~5) so placeholder baseline = cursor baseline.
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 8 + 5)
                    .padding(.top, 8 + 5)
                    .allowsHitTesting(false)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.Radius.regular)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.regular))
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
