import Foundation
import AppKit

@MainActor
public final class ChatController {
    private let state: AppState
    private let engine: any InferenceEngine
    private let store: any ConversationStore
    private let contextManager: ContextManager
    private let tokenCounter: any TokenCounter
    private let systemPrompt: String
    private var generationTask: Task<Void, Never>?

    /// Pending attachments the user has pasted/dropped into the composer.
    public var draftAttachments: [DraftAttachment] = []

    public let imageAnalyzer: any ImageAnalyzing
    public let documentExtractor: any DocumentExtracting

    public init(
        state: AppState,
        engine: any InferenceEngine,
        store: any ConversationStore,
        contextManager: ContextManager,
        tokenCounter: any TokenCounter,
        systemPrompt: String,
        imageAnalyzer: any ImageAnalyzing = ImageAnalyzer(),
        documentExtractor: any DocumentExtracting = DocumentExtractor()
    ) {
        self.state = state
        self.engine = engine
        self.store = store
        self.contextManager = contextManager
        self.tokenCounter = tokenCounter
        self.systemPrompt = systemPrompt
        self.imageAnalyzer = imageAnalyzer
        self.documentExtractor = documentExtractor
    }

    public func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let readyAttachments = draftAttachments.compactMap { $0.attachment }
        guard !trimmed.isEmpty || !readyAttachments.isEmpty,
              state.chatState == .idle else { return }

        draftAttachments.removeAll()
        let convo = ensureActiveConversation(firstUserContent: trimmed)
        let userMessage = ChatMessage(
            role: .user, content: trimmed, attachments: readyAttachments
        )
        append(userMessage, to: convo.id)

        do {
            let fit = try await contextManager.fitToContext(
                systemPrompt: systemPrompt,
                messages: activeMessages(),
                tokenCounter: tokenCounter
            )
            beginGeneration(messages: withSystemPrompt(fit))
        } catch let e as AppError {
            state.lastError = e
        } catch {
            state.lastError = .generationFailed(summary: error.localizedDescription)
        }
    }

    // On app launch, catch up any pre-existing default-titled chats that already
    // have an assistant response — generate titles for them now.
    public func backfillTitles() async {
        for convo in state.conversations {
            guard Self.isDefaultTitle(convo.title),
                  convo.messages.contains(where: { $0.role == .assistant && !$0.content.isEmpty })
            else { continue }
            await generateTitle(for: convo.id)
        }
    }

    public func stop() {
        guard state.chatState == .generating else { return }
        state.chatState = .cancelling
        let engine = self.engine
        Task { await engine.cancelGeneration() }
    }

    public func regenerateLastAssistant() async {
        guard state.chatState == .idle,
              let convoIdx = state.conversations.firstIndex(where: { $0.id == state.activeConversationID }),
              let lastAssistantIdx = state.conversations[convoIdx].messages.lastIndex(where: { $0.role == .assistant })
        else { return }
        state.conversations[convoIdx].messages.remove(at: lastAssistantIdx)
        do {
            let fit = try await contextManager.fitToContext(
                systemPrompt: systemPrompt,
                messages: activeMessages(),
                tokenCounter: tokenCounter
            )
            beginGeneration(messages: withSystemPrompt(fit))
        } catch let e as AppError { state.lastError = e } catch {}
    }

    public func deleteMessage(_ id: UUID) {
        guard let convoIdx = state.conversations.firstIndex(where: { $0.id == state.activeConversationID }) else { return }
        state.conversations[convoIdx].messages.removeAll { $0.id == id }
        state.conversations[convoIdx].updatedAt = .now
        persist(state.conversations[convoIdx])
    }

    private func beginGeneration(messages: [ChatMessage]) {
        // Decide title-gen BEFORE appending the streaming assistant stub —
        // otherwise the stub counts as an assistant message and masks the
        // 'no assistant yet' signal.
        let priorAssistantCount = state.activeConversation?.messages
            .filter({ $0.role == .assistant && !$0.content.isEmpty })
            .count ?? 0
        let shouldGenerateTitle = priorAssistantCount == 0
            || Self.isDefaultTitle(state.activeConversation?.title)
        let activeConvoID = state.activeConversationID

        state.chatState = .generating
        state.awaitingFirstToken = true
        var assistant = ChatMessage(role: .assistant, content: "", status: .streaming)
        append(assistant, to: state.activeConversationID!)

        let engine = self.engine
        let params = GenerationParameters().clamped()
        generationTask = Task { [weak self] in
            guard let self else { return }
            // Batch token UI updates: coalesce every ~16ms so we don't thrash SwiftUI
            // at 200+ tok/s. Buffer in the Task, flush on a clock tick.
            var buffer = ""
            var lastFlush = ContinuousClock.now
            let flushBudget = Duration.milliseconds(16)
            var tokenCount = 0
            var firstTokenAt: ContinuousClock.Instant?
            do {
                for try await ev in engine.generate(messages: messages, parameters: params) {
                    switch ev {
                    case .token(let t):
                        if self.state.awaitingFirstToken {
                            self.state.awaitingFirstToken = false
                            firstTokenAt = ContinuousClock.now
                        }
                        tokenCount += 1
                        buffer += t.text
                        if ContinuousClock.now - lastFlush > flushBudget {
                            assistant.content += buffer; buffer = ""
                            self.updateStreaming(message: assistant)
                            lastFlush = ContinuousClock.now
                        }
                    case .finished(let reason):
                        if !buffer.isEmpty { assistant.content += buffer; buffer = "" }
                        assistant.status = reason == .cancelledByUser || reason == .interruptedByLifecycle ? .interrupted : .complete
                        assistant.stopReason = reason
                        assistant.tokenCount = tokenCount
                        if let start = firstTokenAt {
                            let d = ContinuousClock.now - start
                            assistant.durationMs = Int(d.components.seconds * 1000) +
                                Int(d.components.attoseconds / 1_000_000_000_000_000)
                        }
                        self.finalize(message: assistant)
                    }
                }
            } catch {
                if !buffer.isEmpty { assistant.content += buffer }
                assistant.status = .failed
                assistant.stopReason = .engineError
                self.finalize(message: assistant)
                self.state.lastError = .generationFailed(summary: error.localizedDescription)
            }
            self.state.awaitingFirstToken = false
            // Hold chatState = .generating while title-gen runs so user sends
            // can't race the llama.cpp context. Spec §11: one active gen at a time.
            if shouldGenerateTitle, let cid = activeConvoID {
                await self.generateTitle(for: cid)
            }
            self.state.chatState = .idle
        }
    }

    // Default-title detection — used to decide whether to retrigger AI title gen.
    static func isDefaultTitle(_ title: String?) -> Bool {
        guard let t = title?.trimmingCharacters(in: .whitespacesAndNewlines) else { return true }
        return t.isEmpty || t == "New Chat"
    }

    // Apfel-chat-aligned title generation. Separate system + user messages;
    // first user message only as seed; fall back to first 6 words on error.
    private func generateTitle(for convoID: UUID) async {
        guard let convo = state.conversations.first(where: { $0.id == convoID }),
              let firstUser = convo.messages.first(where: { $0.role == .user })?.content
        else { return }
        let seed = String(firstUser.prefix(400))
        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: "You are a title generator. Respond with ONLY the title, nothing else. 3-5 words maximum. No quotes, no punctuation at the end."),
            ChatMessage(role: .user, content: "Generate a very short title (3-5 words max, no quotes) for a conversation that starts with: \(seed)"),
        ]
        var params = GenerationParameters()
        params.maxTokens = 16
        params.temperature = 0.2
        var collected = ""
        do {
            for try await ev in engine.generate(messages: messages, parameters: params.clamped()) {
                if case .token(let t) = ev { collected += t.text }
                if case .finished = ev { break }
            }
        } catch {
            collected = seed.split(separator: " ").prefix(6).joined(separator: " ")
        }
        let (stripped, _) = OutputSanitizer.stripLeakingMarkers(collected)
        let clean = stripped
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .split(separator: "\n").first.map(String.init) ?? stripped
        guard !clean.isEmpty, clean.count <= 60 else { return }
        if let idx = state.conversations.firstIndex(where: { $0.id == convoID }) {
            state.conversations[idx].title = clean
            state.conversations[idx].updatedAt = .now
            persist(state.conversations[idx])
        }
    }

    // Prepend system prompt so the formatter includes it in the template.
    // fitToContext already reserved tokens for it; this adds the actual message.
    private func withSystemPrompt(_ messages: [ChatMessage]) -> [ChatMessage] {
        guard !systemPrompt.isEmpty else { return messages }
        var result = [ChatMessage(role: .system, content: systemPrompt)]
        result.append(contentsOf: messages)
        return result
    }

    // MARK: - Draft attachment helpers

    public func addImageDraft(_ image: NSImage) {
        let draft = DraftAttachment(
            filename: "image.png",
            fileType: "image",
            thumbnail: image
        )
        draftAttachments.append(draft)
        let analyzer = imageAnalyzer
        Task {
            do {
                let text = try await analyzer.analyze(image)
                let data = image.tiffRepresentation ?? Data()
                draft.attachment = .image(data: data, extractedText: text)
                draft.state = .ready
            } catch {
                draft.state = .error(error.localizedDescription)
            }
        }
    }

    public func addFileDraft(url: URL) {
        let ext = url.pathExtension.lowercased()
        let filename = url.lastPathComponent

        if SupportedFormats.isImage(ext) {
            guard let image = NSImage(contentsOf: url) else { return }
            let draft = DraftAttachment(
                filename: filename, fileType: "image", thumbnail: image
            )
            draftAttachments.append(draft)
            let analyzer = imageAnalyzer
            Task {
                do {
                    let text = try await analyzer.analyze(image)
                    let data = image.tiffRepresentation ?? Data()
                    draft.attachment = .image(data: data, extractedText: text)
                    draft.state = .ready
                } catch { draft.state = .error(error.localizedDescription) }
            }
        } else if SupportedFormats.isDocument(ext) {
            let draft = DraftAttachment(filename: filename, fileType: ext)
            draftAttachments.append(draft)
            let extractor = documentExtractor
            Task {
                do {
                    let result = try await extractor.extract(from: url)
                    draft.attachment = .document(
                        text: result.text, filename: result.filename,
                        fileType: result.fileType
                    )
                    draft.state = .ready
                } catch { draft.state = .error(error.localizedDescription) }
            }
        } else {
            // Unknown extension — try reading as plain text.
            let draft = DraftAttachment(filename: filename, fileType: ext.isEmpty ? "file" : ext)
            draftAttachments.append(draft)
            Task {
                do {
                    let text = try String(contentsOf: url, encoding: .utf8)
                    guard !text.isEmpty else {
                        draft.state = .error("File is empty")
                        return
                    }
                    let truncated = text.count > 32_768
                        ? String(text.prefix(32_768)) + "\n[... truncated at 32K characters]"
                        : text
                    draft.attachment = .document(
                        text: truncated, filename: filename, fileType: ext
                    )
                    draft.state = .ready
                } catch {
                    draft.state = .error("Cannot read file as text")
                }
            }
        }
    }

    public func removeDraft(_ draft: DraftAttachment) {
        draftAttachments.removeAll { $0.id == draft.id }
    }

    // MARK: - conversation mutation helpers

    private func ensureActiveConversation(firstUserContent: String) -> Conversation {
        if let c = state.activeConversation { return c }
        var c = Conversation(title: Conversation.derivedTitle(from: firstUserContent))
        state.conversations.insert(c, at: 0)
        state.activeConversationID = c.id
        persist(c)
        return c
    }

    private func append(_ m: ChatMessage, to convoID: UUID) {
        guard let idx = state.conversations.firstIndex(where: { $0.id == convoID }) else { return }
        state.conversations[idx].messages.append(m)
        state.conversations[idx].updatedAt = .now
        persist(state.conversations[idx])
    }

    private func updateStreaming(message: ChatMessage) {
        guard let convoIdx = state.conversations.firstIndex(where: { $0.id == state.activeConversationID }),
              let msgIdx = state.conversations[convoIdx].messages.firstIndex(where: { $0.id == message.id })
        else { return }
        state.conversations[convoIdx].messages[msgIdx] = message
    }

    private func finalize(message: ChatMessage) {
        updateStreaming(message: message)
        guard let convoIdx = state.conversations.firstIndex(where: { $0.id == state.activeConversationID }) else { return }
        state.conversations[convoIdx].updatedAt = .now
        persist(state.conversations[convoIdx])
    }

    private func activeMessages() -> [ChatMessage] {
        state.activeConversation?.messages ?? []
    }

    private func persist(_ c: Conversation) {
        let store = self.store
        Task.detached(priority: .utility) { try? await store.save(c) }
        recomputeContextCutoff()
    }

    // Mirror of apfel-chat's recomputeContextCutoff. Cheap — walks messages
    // once per state change. Uses character/4 as a token estimate when the
    // message has no measured tokenCount yet (streaming assistant).
    public func recomputeContextCutoff() {
        guard let window = state.contextWindow,
              let msgs = state.activeConversation?.messages, !msgs.isEmpty
        else {
            state.outOfContextMessageIDs = []
            return
        }
        let cutoff = window.cutoffIndex(messages: msgs) { msg in
            msg.tokenCount ?? msg.estimatedTotalTokens
        }
        if let idx = cutoff {
            state.outOfContextMessageIDs = Set(msgs[0..<idx].map(\.id))
        } else {
            state.outOfContextMessageIDs = []
        }
    }
}
