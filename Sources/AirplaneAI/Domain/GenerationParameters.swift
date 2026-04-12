import Foundation

public struct GenerationParameters: Codable, Sendable, Equatable {
    public var temperature: Float
    public var topP: Float
    public var topK: Int
    public var maxTokens: Int
    public var repeatPenalty: Float
    public var seed: Int32

    public init(
        temperature: Float = 0.6,
        topP: Float = 0.95,
        topK: Int = 40,
        maxTokens: Int = 1024,
        repeatPenalty: Float = 1.1,
        seed: Int32 = -1
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.repeatPenalty = repeatPenalty
        self.seed = seed
    }

    public func clamped() -> GenerationParameters {
        var p = self
        if !p.temperature.isFinite { p.temperature = 0.6 }
        if !p.topP.isFinite { p.topP = 0.95 }
        if !p.repeatPenalty.isFinite { p.repeatPenalty = 1.1 }
        p.temperature = max(0.0, min(1.5, p.temperature))
        p.topP = max(0.01, min(1.0, p.topP))
        p.topK = max(1, min(200, p.topK))
        p.maxTokens = max(1, min(4096, p.maxTokens))
        p.repeatPenalty = max(1.0, min(2.0, p.repeatPenalty))
        return p
    }
}
