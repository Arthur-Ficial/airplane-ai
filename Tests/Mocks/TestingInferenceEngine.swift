import Foundation
@testable import AirplaneAI

// Rich configurable engine for E2E tests — richer than MockInferenceEngine.
final class TestingInferenceEngine: InferenceEngine, TokenCounter, @unchecked Sendable {

    enum ResponseMode {
        case scripted([String])
        case repeating(String, count: Int)
        case empty
    }

    var responseMode: ResponseMode = .empty
    var tokenDelay: Duration = .zero
    var firstTokenDelay: Duration = .zero
    var failOnGenerate: Error?
    var failAfterTokenIndex: Int?
    var failOnLoad: Error?
    var tokensPerCharacter: Double = 0.25
    var finalStopReason: StopReason = .completed

    private let lock = NSLock()
    private var _generateCallCount = 0
    private var _cancelCallCount = 0
    private var _lastMessagesReceived: [ChatMessage]?
    private var _loaded = false
    private var _info: ModelInfo?
    private var _cancelled = false

    var generateCallCount: Int { lock.withLock { _generateCallCount } }
    var cancelCallCount: Int { lock.withLock { _cancelCallCount } }
    var lastMessagesReceived: [ChatMessage]? { lock.withLock { _lastMessagesReceived } }

    var isModelLoaded: Bool { get async { lock.withLock { _loaded } } }
    var loadedModelInfo: ModelInfo? { get async { lock.withLock { _info } } }

    func loadModel(at path: URL, contextWindow: Int) async throws {
        if let err = failOnLoad { throw err }
        lock.withLock {
            _loaded = true
            _info = ModelInfo(
                name: "testing-engine",
                sizeBytes: 1,
                sha256: String(repeating: "a", count: 64),
                contextWindow: contextWindow
            )
        }
    }

    func warmup() async {}

    func unloadModel() async {
        lock.withLock { _loaded = false; _info = nil }
    }

    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock {
            _cancelled = false
            _generateCallCount += 1
            _lastMessagesReceived = messages
        }
        let tokens = resolvedTokens()
        let tDelay = tokenDelay
        let ftDelay = firstTokenDelay
        let failGen = failOnGenerate
        let failIdx = failAfterTokenIndex
        let stop = finalStopReason

        return AsyncThrowingStream { continuation in
            let task = Task {
                if let err = failGen {
                    continuation.finish(throwing: err); return
                }
                for (i, text) in tokens.enumerated() {
                    if Task.isCancelled || self.cancelledFlag() {
                        continuation.yield(.finished(.cancelledByUser))
                        continuation.finish(); return
                    }
                    if let idx = failIdx, i > idx {
                        continuation.finish(throwing: AppError.generationFailed(summary: "injected mid-stream"))
                        return
                    }
                    let delay = i == 0 ? ftDelay : tDelay
                    if delay != .zero { try await Task.sleep(for: delay) }
                    continuation.yield(.token(TokenChunk(text: text, tokenID: Int32(i), index: i)))
                }
                continuation.yield(.finished(stop))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancelGeneration() async {
        lock.withLock { _cancelled = true }
    }

    func countTokens(in text: String) async throws -> Int {
        max(1, Int((Double(text.count) * tokensPerCharacter).rounded(.up)))
    }

    private func cancelledFlag() -> Bool { lock.withLock { _cancelled } }

    private func resolvedTokens() -> [String] {
        switch responseMode {
        case .scripted(let tokens): return tokens
        case .repeating(let token, let count): return Array(repeating: token, count: count)
        case .empty: return []
        }
    }
}
