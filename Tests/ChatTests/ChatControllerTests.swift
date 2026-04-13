import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("ChatController")
struct ChatControllerTests {
    private func makeController() -> (ChatController, AppState, MockInferenceEngine, MockConversationStore) {
        let state = AppState()
        let engine = MockInferenceEngine()
        let store = MockConversationStore()
        let controller = ChatController(
            state: state,
            engine: engine,
            store: store,
            contextManager: ContextManager(maxContextTokens: 8192),
            tokenCounter: MockTokenCounter(),
            systemPrompt: "You are Airplane AI."
        )
        return (controller, state, engine, store)
    }

    @Test func sendCreatesConversationAndStreamsAssistant() async {
        let (c, state, engine, _) = makeController()
        engine.scriptedTokens = ["Hello", " ", "there"]
        await c.send("hi")
        // Poll for completion — robust under parallel test load.
        for _ in 0..<100 {
            if state.chatState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(state.conversations.count == 1)
        let messages = state.activeConversation?.messages ?? []
        #expect(messages.count == 2)
        #expect(messages.first?.role == .user)
        #expect(messages.last?.role == .assistant)
        #expect(messages.last?.content == "Hello there")
        #expect(messages.last?.status == .complete)
    }

    @Test func stopMarksAssistantInterrupted() async {
        let (c, state, engine, _) = makeController()
        engine.scriptedTokens = Array(repeating: "x", count: 500)
        engine.perTokenDelayNanos = 5_000_000  // 5ms/token = 2.5s total — enough time to cancel
        await c.send("hello")
        // Wait for streaming to actually start before stopping.
        for _ in 0..<50 {
            if state.chatState == .generating { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        c.stop()
        // Wait for finalization
        for _ in 0..<50 {
            if state.chatState == .idle { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let last = state.activeConversation?.messages.last
        #expect(last?.role == .assistant)
        #expect(last?.status == .interrupted)
        #expect(last?.stopReason == .cancelledByUser)
    }

    @Test func emptyInputIsIgnored() async {
        let (c, state, _, _) = makeController()
        await c.send("   \n\t  ")
        #expect(state.conversations.isEmpty)
    }

    @Test func titleDerivedFromFirstUserMessage() async {
        let (c, state, _, _) = makeController()
        await c.send("What is the capital of Austria?")
        #expect(state.activeConversation?.title.contains("What is") == true)
    }
}
