import Foundation
@testable import AirplaneAI

final class MockInferenceEngine: InferenceEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var _loaded = false
    private var _info: ModelInfo?
    private var _cancelled = false

    // Script what generate() emits.
    var scriptedTokens: [String] = ["Hello", ", ", "world", "!"]
    var perTokenDelayNanos: UInt64 = 0
    var injectedFailure: Error?
    var finalStopReason: StopReason = .completed

    var isModelLoaded: Bool { get async { lock.withLock { _loaded } } }
    var loadedModelInfo: ModelInfo? { get async { lock.withLock { _info } } }

    func loadModel(at path: URL, contextWindow: Int) async throws {
        if let err = injectedFailure { throw err }
        lock.withLock {
            _loaded = true
            _info = ModelInfo(name: "mock", sizeBytes: 1, sha256: String(repeating: "0", count: 64), contextWindow: contextWindow)
        }
    }

    func unloadModel() async { lock.withLock { _loaded = false; _info = nil } }

    func generate(messages: [ChatMessage], parameters: GenerationParameters) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock { _cancelled = false }
        let tokens = scriptedTokens
        let delay = perTokenDelayNanos
        let failure = injectedFailure
        let stop = finalStopReason
        return AsyncThrowingStream { continuation in
            let task = Task {
                if let err = failure { continuation.finish(throwing: err); return }
                for (i, tok) in tokens.enumerated() {
                    if Task.isCancelled || self.cancelledFlag() {
                        continuation.yield(.finished(.cancelledByUser)); continuation.finish(); return
                    }
                    if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
                    continuation.yield(.token(TokenChunk(text: tok, tokenID: Int32(i), index: i)))
                }
                continuation.yield(.finished(stop))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancelGeneration() async { lock.withLock { _cancelled = true } }
    func countTokens(in text: String) async throws -> Int { max(1, text.count / 4) }

    private func cancelledFlag() -> Bool { lock.withLock { _cancelled } }
}
