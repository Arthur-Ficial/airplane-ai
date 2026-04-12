import Foundation

public struct TokenChunk: Sendable, Equatable {
    public let text: String
    public let tokenID: Int32?
    public let index: Int
    public let tokensPerSecond: Double?

    public init(text: String, tokenID: Int32? = nil, index: Int, tokensPerSecond: Double? = nil) {
        self.text = text
        self.tokenID = tokenID
        self.index = index
        self.tokensPerSecond = tokensPerSecond
    }
}

public enum StreamEvent: Sendable, Equatable {
    case token(TokenChunk)
    case finished(StopReason)
}

public protocol InferenceEngine: Sendable {
    func loadModel(at path: URL, contextWindow: Int) async throws
    func unloadModel() async
    var isModelLoaded: Bool { get async }
    var loadedModelInfo: ModelInfo? { get async }

    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters
    ) -> AsyncThrowingStream<StreamEvent, Error>

    func cancelGeneration() async
    func countTokens(in text: String) async throws -> Int
}
