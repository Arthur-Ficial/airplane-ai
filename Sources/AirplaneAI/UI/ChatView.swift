import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChatView: View {
    let state: AppState
    let controller: ChatController
    let audioPreferences: AudioPreferences
    let speechInput: LiveSpeechInput
    let speechOutput: SpeechOutput
    @State private var composer = ComposerModel()
    @State private var lastSpokenMessageID: UUID? = nil
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
                    .id(state.activeConversationID)
            }
            InputBar(
                state: state,
                controller: controller,
                speechInput: speechInput,
                composer: composer,
                focused: $composerFocused,
                onSubmit: submit,
                onStop: stop
            )
            DisclaimerFooter()
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
            lastSpokenMessageID = nil
        }
        .onChange(of: state.chatState) { old, new in
            guard audioPreferences.speechOutputEnabled else { return }
            guard old == .generating, new == .idle else { return }
            guard let last = state.activeConversation?.messages.last,
                  last.role == .assistant,
                  last.status == .complete,
                  last.id != lastSpokenMessageID else { return }
            lastSpokenMessageID = last.id
            speechOutput.speak(last.content)
        }
    }

    private func messageList(messages: [ChatMessage]) -> some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                messageScroll(messages: messages, proxy: proxy)
                if !isFollowingTail && !ScreenshotMode.isEnabled {
                    Button {
                        withAnimation(.easeOut(duration: Metrics.Duration.quickAnimation)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                            .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 14)
                    .padding(.bottom, 8)
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
                    let dividerBeforeIDs = computeDividerIDs(messages: messages)
                    ForEach(messages) { msg in
                        let outOfContext = state.outOfContextMessageIDs.contains(msg.id)
                        if dividerBeforeIDs.contains(msg.id) {
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
                                composer.prepend(quoted)
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
        let text = composer.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAttachments = !controller.draftAttachments.isEmpty
        guard !text.isEmpty || hasAttachments else { return }
        composer.clear()
        Task {
            await controller.send(text)
            composerFocused = true
        }
    }

    private func stop() { controller.stop() }

    // Divider marks the boundary between the trailing out-of-context messages and
    // the first in-context message. Precompute the IDs that should render a divider
    // BEFORE them so ForEach can test in O(1) without allocating an enumerated copy.
    private func computeDividerIDs(messages: [ChatMessage]) -> Set<UUID> {
        var result = Set<UUID>()
        var previousWasOOC = false
        for msg in messages {
            let isOOC = state.outOfContextMessageIDs.contains(msg.id)
            if previousWasOOC && !isOOC { result.insert(msg.id) }
            previousWasOOC = isOOC
        }
        return result
    }

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
    let speechInput: LiveSpeechInput
    let composer: ComposerModel
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
            VStack(alignment: .leading, spacing: 6) {
                if speechInput.isListening {
                    ListeningIndicator(transcriptIsEmpty: speechInput.transcript.isEmpty)
                        .transition(.opacity)
                }
                HStack(alignment: .bottom, spacing: Metrics.Composer.gap) {
                    editor
                    VStack(spacing: 2) {
                        SendButton(
                            generating: state.chatState == .generating,
                            canSend: !composer.draft.isEmpty || !controller.draftAttachments.isEmpty,
                            awaitingFirstToken: state.awaitingFirstToken,
                            onTap: state.chatState == .generating ? onStop : onSubmit
                        )
                        HStack(spacing: 2) {
                            MicButton(speechInput: speechInput) { _ in }
                            attachButton
                        }
                    }
                    .padding(.bottom, 2)
                }
                if let errorMessage = speechInput.errorMessage, !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.leading, 2)
                }
            }
            .padding(.horizontal, Metrics.Composer.horizontalPadding)
            .padding(.vertical, Metrics.Composer.verticalPadding)
            .overlay(resizeHandle, alignment: .topTrailing)
        }
        .onAppear {
            if !ScreenshotMode.isEnabled {
                focused.wrappedValue = true
            }
        }
        .onChange(of: speechInput.isListening) { _, listening in
            if listening {
                composer.captureBeforeListening()
                focused.wrappedValue = true
            }
        }
        .onChange(of: speechInput.transcript) { _, text in
            guard speechInput.isListening else { return }
            composer.applyLivePartial(text)
        }
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
            text: Binding(get: { composer.draft }, set: { composer.draft = $0 }),
            placeholder: placeholder,
            isFocused: focused.wrappedValue,
            sendOnEnter: sendWith != "cmd-enter",
            onSend: {
                if state.chatState == .generating { onStop() } else { onSubmit() }
            },
            onCancel: {
                if state.chatState == .generating { onStop() }
                else if !composer.draft.isEmpty { composer.clear() }
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

private struct ListeningIndicator: View {
    let transcriptIsEmpty: Bool
    @State private var dotPhase: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            if transcriptIsEmpty {
                Text("Listening" + String(repeating: ".", count: dotPhase + 1))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onAppear { if !reduceMotion { startDotAnimation() } }
            } else {
                Text("Listening…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.accentColor.opacity(0.12))
        )
        .accessibilityLabel("Listening")
    }

    private func startDotAnimation() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                dotPhase = (dotPhase + 1) % 3
            }
        }
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
