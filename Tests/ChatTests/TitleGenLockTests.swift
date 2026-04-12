import Foundation
import Testing
@testable import AirplaneAI

// Regression test for #62: title-gen must hold chatState = .generating while
// running, and must invoke engine.generate() a second time after the main
// response finishes.
@MainActor
@Suite("Title-gen locks chatState")
struct TitleGenLockTests {
    @Test func titleGenFiresSecondGenerateCall() async throws {
        let state = AppState()
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["A"]
        let store = MockConversationStore()
        let controller = ChatController(
            state: state, engine: engine, store: store,
            contextManager: ContextManager(maxContextTokens: 4096),
            tokenCounter: MockTokenCounter(),
            systemPrompt: "Test"
        )

        await controller.send("Hi")
        // Let the full flow settle.
        for _ in 0..<300 {
            if state.chatState == .idle, engine.generateCallCount >= 2 { break }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }

        #expect(engine.generateCallCount == 2, "expected main-gen + title-gen, got \(engine.generateCallCount)")
        #expect(state.chatState == .idle, "chatState should return to .idle after title-gen")
    }
}
