import Foundation
import Testing
@testable import AirplaneAI

@Suite("GenerationParameters")
struct GenerationParametersTests {
    @Test func defaultsAreSensible() {
        let p = GenerationParameters()
        #expect(p.temperature == 0.6)
        #expect(p.topP == 0.95)
        #expect(p.topK == 40)
        #expect(p.maxTokens == 1024)
        #expect(p.repeatPenalty == 1.1)
        #expect(p.seed == -1)
    }

    @Test func clampedRejectsNaN() {
        var p = GenerationParameters()
        p.temperature = .nan
        p.topP = .nan
        p.repeatPenalty = .nan
        let c = p.clamped()
        #expect(c.temperature == 0.6)
        #expect(c.topP == 0.95)
        #expect(c.repeatPenalty == 1.1)
    }

    @Test func clampedRanges() {
        let hi = GenerationParameters(temperature: 99, topP: 99, topK: 9999, maxTokens: 99999, repeatPenalty: 99).clamped()
        #expect(hi.temperature == 1.5)
        #expect(hi.topP == 1.0)
        #expect(hi.topK == 200)
        #expect(hi.maxTokens == 4096)
        #expect(hi.repeatPenalty == 2.0)

        let lo = GenerationParameters(temperature: -5, topP: 0, topK: 0, maxTokens: 0, repeatPenalty: 0).clamped()
        #expect(lo.temperature == 0.0)
        #expect(lo.topP == 0.01)
        #expect(lo.topK == 1)
        #expect(lo.maxTokens == 1)
        #expect(lo.repeatPenalty == 1.0)
    }
}
