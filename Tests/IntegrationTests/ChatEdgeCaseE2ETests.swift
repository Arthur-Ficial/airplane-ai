import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("Chat edge cases", .serialized)
struct ChatEdgeCaseE2ETests {

    private func makeController() -> (ChatController, AppState, TestingInferenceEngine) {
        let state = AppState()
        state.contextWindow = ContextWindow(
            modelCapability: 8192, appDefault: 8192, effective: 8192
        )
        let engine = TestingInferenceEngine()
        engine.responseMode = .scripted(["Hello", " ", "there"])
        let store = MockConversationStore()
        let controller = ChatController(
            state: state,
            engine: engine,
            store: store,
            contextManager: ContextManager(maxContextTokens: 8192),
            tokenCounter: engine,
            systemPrompt: "You are Airplane AI.",
            imageAnalyzer: MockImageAnalyzer(),
            documentExtractor: MockDocumentExtractor()
        )
        return (controller, state, engine)
    }

    private func waitIdle(_ state: AppState) async {
        for _ in 0..<200 {
            if state.chatState == .idle { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test func rapidSendCancelCycles() async {
        let (c, state, engine) = makeController()
        engine.responseMode = .repeating("x", count: 500)
        engine.tokenDelay = .milliseconds(5)
        for _ in 0..<5 {
            await c.send("go")
            // Brief wait for generation to start.
            for _ in 0..<20 {
                if state.chatState == .generating { break }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            c.stop()
            await waitIdle(state)
        }
        // Must reach idle without crash.
        #expect(state.chatState == .idle)
    }

    @Test func sendDuringGenerationIsRejected() async {
        let (c, state, engine) = makeController()
        engine.responseMode = .repeating("w", count: 200)
        engine.tokenDelay = .milliseconds(10)
        await c.send("first")
        // Wait for generation to actually start.
        for _ in 0..<50 {
            if state.chatState == .generating { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(state.chatState == .generating)
        // Second send should be rejected (guard chatState == .idle fails).
        await c.send("second")
        await waitIdle(state)
        let msgs = state.activeConversation?.messages ?? []
        let userMsgs = msgs.filter { $0.role == .user }
        #expect(userMsgs.count == 1, "Second send should be rejected during generation")
    }

    @Test func whitespaceOnlyRejected() async {
        let (c, state, _) = makeController()
        await c.send("  \n\t")
        #expect(state.conversations.isEmpty, "Whitespace-only input should not create a conversation")
    }

    @Test func backToBackGenerations() async {
        let (c, state, engine) = makeController()
        engine.responseMode = .scripted(["A"])
        await c.send("one")
        await waitIdle(state)
        engine.responseMode = .scripted(["B"])
        await c.send("two")
        await waitIdle(state)
        engine.responseMode = .scripted(["C"])
        await c.send("three")
        await waitIdle(state)
        let msgs = state.activeConversation?.messages ?? []
        // 3 user + 3 assistant = 6 messages.
        #expect(msgs.count == 6)
        let userMsgs = msgs.filter { $0.role == .user }
        let assistantMsgs = msgs.filter { $0.role == .assistant }
        #expect(userMsgs.count == 3)
        #expect(assistantMsgs.count == 3)
    }

    @Test func titleGenerationRuns() async {
        let (c, state, engine) = makeController()
        engine.responseMode = .scripted(["Helpful", " ", "response"])
        await c.send("What is the meaning of life?")
        await waitIdle(state)
        // Title gen triggers a second generate() call after the first completes.
        // generateCallCount should be 2 (one for response, one for title).
        #expect(engine.generateCallCount == 2,
                "Expected 2 generate calls: response + title")
    }

    @Test func emptyContentWithoutAttachmentsRejected() async {
        let (c, state, _) = makeController()
        await c.send("")
        #expect(state.conversations.isEmpty,
                "Empty text with no attachments should not create a conversation")
    }
}
