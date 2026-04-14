import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("Engine error recovery", .serialized)
struct EngineErrorRecoveryTests {

    private func makeController() -> (ChatController, AppState, TestingInferenceEngine, MockTokenCounter) {
        let state = AppState()
        state.contextWindow = ContextWindow(
            modelCapability: 8192, appDefault: 8192, effective: 8192
        )
        let engine = TestingInferenceEngine()
        engine.responseMode = .scripted(["Hello", " ", "world"])
        let tc = MockTokenCounter()
        let store = MockConversationStore()
        let controller = ChatController(
            state: state,
            engine: engine,
            store: store,
            contextManager: ContextManager(maxContextTokens: 8192),
            tokenCounter: tc,
            systemPrompt: "You are Airplane AI.",
            imageAnalyzer: MockImageAnalyzer(),
            documentExtractor: MockDocumentExtractor()
        )
        return (controller, state, engine, tc)
    }

    private func waitIdle(_ state: AppState) async {
        for _ in 0..<200 {
            if state.chatState == .idle { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @Test func engineErrorMidStream() async {
        let (c, state, engine, _) = makeController()
        engine.responseMode = .scripted(["one", "two", "three", "four", "five"])
        engine.failAfterTokenIndex = 3
        await c.send("hi")
        await waitIdle(state)
        let msgs = state.activeConversation?.messages ?? []
        let assistant = msgs.last { $0.role == .assistant }
        #expect(assistant?.status == .failed)
        #expect(assistant?.stopReason == .engineError)
        #expect(state.lastError != nil)
    }

    @Test func recoveryAfterError() async {
        let (c, state, engine, _) = makeController()
        // First: trigger a mid-stream error.
        engine.responseMode = .scripted(["tok1", "tok2", "tok3"])
        engine.failAfterTokenIndex = 1
        await c.send("first")
        await waitIdle(state)
        #expect(state.lastError != nil)
        // Second: clear the failure and send again — should succeed.
        engine.failAfterTokenIndex = nil
        state.lastError = nil
        engine.responseMode = .scripted(["Good", " ", "answer"])
        await c.send("second")
        await waitIdle(state)
        #expect(state.lastError == nil)
        let msgs = state.activeConversation?.messages ?? []
        let assistants = msgs.filter { $0.role == .assistant }
        let lastAssistant = assistants.last
        #expect(lastAssistant?.status == .complete)
        #expect(lastAssistant?.content == "Good answer")
    }

    @Test func tokenCounterFailure() async {
        let (c, state, _, tc) = makeController()
        tc.injectedFailure = AppError.generationFailed(summary: "token counter failed")
        await c.send("test message")
        await waitIdle(state)
        #expect(state.lastError != nil)
    }
}
