import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatView: View {
    let state: AppState
    let controller: ChatController
    @State private var draft: String = ""
    @State private var isFollowingTail = true
    @State private var lastScrollTime: ContinuousClock.Instant = .now
    @FocusState private var composerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("airplane.showTokenCounts") private var showTokenCounts: Bool = true

    var body: some View {
        let messages = state.activeConversation?.messages ?? []
        VStack(spacing: 0) {
            if messages.isEmpty {
                WelcomeView()
            } else {
                messageList(messages: messages)
            }
            InputBar(
                state: state,
                controller: controller,
                draft: $draft,
                focused: $composerFocused,
                onSubmit: submit,
                onStop: stop
            )
        }
        .onDrop(of: [.fileURL, .image], isTargeted: nil, perform: handleDrop)
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

    private func messageList(messages: [ChatMessage]) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                messageScroll(messages: messages, proxy: proxy)
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
                    .help(L.scrollToLatest)
                    .accessibilityLabel(L.scrollToLatestMessage)
                    .transition(.opacity)
                }
            }
        }
    }

    private func messageScroll(messages: [ChatMessage], proxy: ScrollViewProxy) -> some View {
            ScrollView {
                LazyVStack(spacing: Metrics.Padding.large) {
                    let lastAssistantID = messages.last(where: { $0.role == .assistant })?.id
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                        let outOfContext = state.outOfContextMessageIDs.contains(msg.id)
                        // Divider BETWEEN the last out-of-context message and the first in-context one.
                        if !outOfContext, index > 0,
                           state.outOfContextMessageIDs.contains(messages[index - 1].id) {
                            contextCutoffDivider
                        }
                        MessageBubble(
                            message: msg,
                            isLastAssistant: msg.id == lastAssistantID,
                            isOutOfContext: outOfContext,
                            showTokenCounts: showTokenCounts,
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
            .onChange(of: messages.count) { old, new in
                guard new > old else { return }
                let userJustSent = messages.last?.role == .user
                guard isFollowingTail || new <= 2 || userJustSent else { return }
                if reduceMotion {
                    proxy.scrollTo("bottom", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: Metrics.Duration.quickAnimation)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: messages.last?.content) { _, _ in
                guard isFollowingTail else { return }
                let now = ContinuousClock.now
                guard now - lastScrollTime > .milliseconds(100) else { return }
                lastScrollTime = now
                proxy.scrollTo("bottom", anchor: .bottom)
            }
    }

    private func submit() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !controller.draftAttachments.isEmpty
        guard !text.isEmpty || hasAttachments else { return }
        draft = ""
        Task {
            await controller.send(text)
            composerFocused = true
        }
    }

    private func stop() { controller.stop() }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                provider.loadObject(ofClass: NSURL.self) { item, _ in
                    guard let nsURL = item as? NSURL,
                          let url = nsURL as URL?
                    else { return }
                    Task { @MainActor in controller.addFileDraft(url: url) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                provider.loadObject(ofClass: NSImage.self) { item, _ in
                    guard let image = item as? NSImage else { return }
                    Task { @MainActor in controller.addImageDraft(image) }
                }
            }
        }
        return true
    }

    private var contextCutoffDivider: some View {
        HStack(spacing: 8) {
            Rectangle().frame(height: 1).foregroundStyle(.orange.opacity(0.4))
            Text(L.contextCutoffNotice)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
                .fixedSize()
            Rectangle().frame(height: 1).foregroundStyle(.orange.opacity(0.4))
        }
        .padding(.horizontal, 16)
    }
}

struct InputBar: View {
    let state: AppState
    let controller: ChatController
    @Binding var draft: String
    var focused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onStop: () -> Void
    @AppStorage("airplane.sendWith") private var sendWith: String = "enter"

    @State private var composerHeight: CGFloat = Metrics.Composer.minHeight
    @State private var showFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            AttachmentStrip(
                drafts: controller.draftAttachments,
                onRemove: { controller.removeDraft($0) }
            )
            HStack(alignment: .bottom, spacing: Metrics.Composer.gap) {
                editor
                VStack(spacing: 4) {
                    SendButton(
                        generating: state.chatState == .generating,
                        canSend: !draft.isEmpty || !controller.draftAttachments.isEmpty,
                        awaitingFirstToken: state.awaitingFirstToken,
                        onTap: state.chatState == .generating ? onStop : onSubmit
                    )
                    attachButton
                }
                .padding(.bottom, 4)
            }
            .padding(.horizontal, Metrics.Composer.horizontalPadding)
            .padding(.vertical, Metrics.Composer.verticalPadding)
            .overlay(resizeHandle, alignment: .topTrailing)
        }
        .onAppear { focused.wrappedValue = true }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: SupportedFormats.allowedContentTypes,
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                // Copy to temp while sandbox access is valid — addFileDraft reads async.
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tmp)
                try? FileManager.default.copyItem(at: url, to: tmp)
                url.stopAccessingSecurityScopedResource()
                controller.addFileDraft(url: tmp)
            }
        }
    }

    // Custom NSTextView — textContainerInset + lineFragmentPadding both zero.
    // Placeholder is drawn INSIDE the same text container at the same origin
    // as the cursor, so by construction they can never disagree.
    private var editor: some View {
        ComposerTextView(
            text: $draft,
            placeholder: placeholder,
            isFocused: focused.wrappedValue,
            sendOnEnter: sendWith != "cmd-enter",
            onSend: {
                if state.chatState == .generating { onStop() } else { onSubmit() }
            },
            onCancel: {
                if state.chatState == .generating { onStop() }
                else if !draft.isEmpty { draft = "" }
            },
            onPasteImage: { image in controller.addImageDraft(image) }
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(height: composerHeight)
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

    private var attachButton: some View {
        Button { showFilePicker = true } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Metrics.Size.sendButton, height: Metrics.Size.sendButton)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Attach file")
        .accessibilityLabel("Attach file")
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
