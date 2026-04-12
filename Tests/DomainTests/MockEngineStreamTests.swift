import Foundation
import Testing
@testable import AirplaneAI

@Suite("MockInferenceEngine stream")
struct MockEngineStreamTests {
    @Test func streamYieldsScriptedTokensThenFinished() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["A", "B", "C"]
        var collected: [String] = []
        var finish: StopReason?
        for try await ev in engine.generate(messages: [], parameters: .init()) {
            switch ev {
            case .token(let t): collected.append(t.text)
            case .finished(let r): finish = r
            }
        }
        #expect(collected == ["A", "B", "C"])
        #expect(finish == .completed)
    }

    @Test func cancelMidStreamProducesCancelledByUser() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = Array(repeating: "x", count: 200)
        engine.perTokenDelayNanos = 2_000_000 // 2ms

        // Start consumer, cancel after a few tokens have been seen.
        var finish: StopReason?
        var tokenCount = 0
        for try await ev in engine.generate(messages: [], parameters: .init()) {
            switch ev {
            case .token:
                tokenCount += 1
                if tokenCount == 3 { await engine.cancelGeneration() }
            case .finished(let r):
                finish = r
            }
        }
        #expect(finish == .cancelledByUser)
    }

    @Test func injectedFailurePropagates() async {
        struct Boom: Error {}
        let engine = MockInferenceEngine()
        engine.injectedFailure = Boom()
        var threw = false
        do {
            for try await _ in engine.generate(messages: [], parameters: .init()) {}
        } catch { threw = true }
        #expect(threw)
    }
}
