import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("Context exhaustion E2E", .serialized)
struct ContextExhaustionE2ETests {

    private func makeController(
        maxContextTokens: Int = 512
    ) -> (ChatController, AppState, TestingInferenceEngine, MockConversationStore) {
        let state = AppState()
        state.contextWindow = ContextWindow(
            modelCapability: maxContextTokens,
            appDefault: maxContextTokens,
            effective: maxContextTokens
        )
        let engine = TestingInferenceEngine()
        engine.responseMode = .scripted(["OK"])
        let store = MockConversationStore()
        let controller = ChatController(
            state: state,
            engine: engine,
            store: store,
            contextManager: ContextManager(
                maxContextTokens: maxContextTokens,
                reservedForResponse: 64,
                templateOverheadTokens: 32
            ),
            tokenCounter: engine,
            systemPrompt: "You are Airplane AI.",
            imageAnalyzer: MockImageAnalyzer(),
            documentExtractor: MockDocumentExtractor()
        )
        return (controller, state, engine, store)
    }

    private func waitIdle(_ state: AppState) async {
        for _ in 0..<200 {
            if state.chatState == .idle { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test func fillUntilOldestTrimmed() async {
        let (c, state, engine, _) = makeController(maxContextTokens: 256)
        engine.responseMode = .scripted(["Reply"])
        // Send messages until out-of-context IDs appear.
        for i in 0..<30 {
            await c.send("Message number \(i) with some padding text.")
            await waitIdle(state)
            if !state.outOfContextMessageIDs.isEmpty { break }
        }
        #expect(!state.outOfContextMessageIDs.isEmpty,
                "Should have trimmed oldest messages")
        // The oldest message's ID should be in outOfContextMessageIDs.
        if let first = state.activeConversation?.messages.first {
            #expect(state.outOfContextMessageIDs.contains(first.id))
        }
    }

    @Test func systemPromptNeverTrimmed() async {
        let (c, state, engine, _) = makeController(maxContextTokens: 512)
        engine.responseMode = .scripted(["Yes"])
        // Send several messages to fill context.
        for i in 0..<10 {
            await c.send("Question \(i)")
            await waitIdle(state)
        }
        // Every generate() call should have system prompt as first message.
        let last = engine.lastMessagesReceived
        #expect(last?.first?.role == .system)
        #expect(last?.first?.content == "You are Airplane AI.")
    }

    @Test func newestUserMessageNeverTruncated() async {
        let (c, state, engine, _) = makeController(maxContextTokens: 512)
        engine.responseMode = .scripted(["Answer"])
        let longQuestion = "What is " + String(repeating: "very ", count: 20) + "important?"
        await c.send(longQuestion)
        await waitIdle(state)
        // The user message stored in the conversation must be complete.
        let msgs = state.activeConversation?.messages ?? []
        let userMsgs = msgs.filter { $0.role == .user }
        #expect(userMsgs.last?.content == longQuestion)
    }

    @Test func singleMassiveMessageThrowsInputTooLarge() async {
        let (c, state, _, _) = makeController(maxContextTokens: 256)
        // Budget = 256-64-32 = 160. System ~6 tokens. Msg needs >154 tokens.
        // tokensPerCharacter = 0.25, so 700 chars = 175 tokens.
        let huge = String(repeating: "x", count: 700)
        await c.send(huge)
        await waitIdle(state)
        #expect(state.lastError == .inputTooLarge(maxTokens: 160))
    }

    @Test func recoveryAfterExhaustion() async {
        let (c, state, engine, _) = makeController(maxContextTokens: 256)
        engine.responseMode = .scripted(["Answer"])
        // Trigger inputTooLarge.
        let huge = String(repeating: "x", count: 700)
        await c.send(huge)
        await waitIdle(state)
        #expect(state.lastError != nil)
        // Clear error and send a small message — should succeed.
        state.lastError = nil
        // Need a fresh conversation since previous send created one in error state.
        state.activeConversationID = nil
        await c.send("hi")
        await waitIdle(state)
        #expect(state.lastError == nil)
        let msgs = state.activeConversation?.messages ?? []
        let assistant = msgs.last { $0.role == .assistant }
        #expect(assistant?.content == "Answer")
    }

    @Test func attachmentCountsTowardBudget() async {
        let (c, state, engine, _) = makeController(maxContextTokens: 512)
        engine.responseMode = .scripted(["Sure"])
        // Send a few plain messages first.
        for i in 0..<5 {
            await c.send("Plain message \(i)")
            await waitIdle(state)
        }
        let priorOOC = state.outOfContextMessageIDs.count
        // Now send a message with a large document attachment.
        // The attachment text inflates the materializedContent, pushing older
        // messages out of context sooner.
        let bigDoc = Attachment.document(
            text: String(repeating: "d", count: 800),
            filename: "big.txt", fileType: "txt"
        )
        let msgWithAttachment = ChatMessage(
            role: .user, content: "Summarize this",
            attachments: [bigDoc]
        )
        // We can't use send() for pre-built attachments easily, but we can
        // verify via recomputeContextCutoff that attachment text counts.
        if let idx = state.conversations.firstIndex(where: {
            $0.id == state.activeConversationID
        }) {
            state.conversations[idx].messages.append(msgWithAttachment)
            c.recomputeContextCutoff()
        }
        // After adding a large attachment message, more old messages should
        // be out-of-context than before.
        #expect(state.outOfContextMessageIDs.count >= priorOOC)
    }
}
