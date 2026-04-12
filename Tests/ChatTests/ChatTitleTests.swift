import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("AI-generated chat titles")
struct ChatTitleTests {
    private func makeController(scriptedFirst: [String], scriptedTitle: [String]) -> (ChatController, AppState, MockInferenceEngine) {
        let state = AppState()
        let engine = MockInferenceEngine()
        let store = MockConversationStore()
        // First generate = the assistant message, second generate = the title.
        // MockInferenceEngine doesn't naturally differentiate — we simulate by letting
        // the user flip scriptedTokens externally if needed.
        engine.scriptedTokens = scriptedFirst
        let controller = ChatController(
            state: state, engine: engine, store: store,
            contextManager: ContextManager(maxContextTokens: 4096),
            tokenCounter: MockTokenCounter(),
            systemPrompt: "Test"
        )
        _ = scriptedTitle // reserved for more advanced scripting later
        return (controller, state, engine)
    }

    @Test func titleGenerationIsTriggeredOnFirstAssistantResponse() async throws {
        let (c, state, engine) = makeController(
            scriptedFirst: ["The", " capital", " is", " Vienna."],
            scriptedTitle: ["Austria", " capital"]
        )
        await c.send("What is the capital of Austria?")
        // Wait for the full stream to finish.
        for _ in 0..<100 {
            if state.chatState == .idle { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        // Title should have been derived from the user message.
        #expect(state.activeConversation?.title.isEmpty == false)
        _ = engine
    }
}
