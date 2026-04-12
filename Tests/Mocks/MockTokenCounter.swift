import Foundation
@testable import AirplaneAI

final class MockTokenCounter: TokenCounter, @unchecked Sendable {
    // Tokens per character ratio — tune in tests as needed.
    var tokensPerCharacter: Double = 0.25
    var injectedFailure: Error?

    init(tokensPerCharacter: Double = 0.25) {
        self.tokensPerCharacter = tokensPerCharacter
    }

    func countTokens(in text: String) async throws -> Int {
        if let err = injectedFailure { throw err }
        return max(1, Int((Double(text.count) * tokensPerCharacter).rounded(.up)))
    }
}
