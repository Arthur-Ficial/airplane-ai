import Foundation
import Testing
@testable import AirplaneAI

// Integration test against the REAL bundled Gemma E4B GGUF. Skipped if the
// model isn't present (CI without model bundle).
@Suite("LlamaSwiftEngine integration")
struct LlamaEngineIntegrationTests {

    private func findModel() -> URL? {
        if let u = ModelLocator.bundledModelURL() { return u }
        // Dev fallback: absolute path from repo root.
        let dev = URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/Sources/AirplaneAI/Resources/models/airplane-model.gguf")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    @Test func loadGenerateCancel() async throws {
        guard let url = findModel() else {
            print("→ skip: model file not present")
            return
        }
        let engine = LlamaSwiftEngine()
        try await engine.loadModel(at: url, contextWindow: 2048)
        defer { Task { await engine.unloadModel() } }

        let messages = [ChatMessage(role: .user, content: "Say hi in one word.")]
        var params = GenerationParameters()
        params.maxTokens = 8
        params.temperature = 0.0
        params.seed = 42

        var first: String?
        var done: StopReason?
        var count = 0
        for try await ev in engine.generate(messages: messages, parameters: params) {
            switch ev {
            case .token(let t):
                count += 1
                if first == nil { first = t.text }
            case .finished(let r):
                done = r
            }
            if count >= 8 { await engine.cancelGeneration() }
        }
        #expect(count > 0, "expected at least one token")
        #expect(done != nil)
    }
}
