import Foundation
@testable import AirplaneAI

final class MockTokenCounter: TokenCounter, @unchecked Sendable {
    var tokensPerCharacter: Double = 0.25
    var injectedFailure: Error?
    var overrideCounts: [String: Int] = [:]
    var perCallDelay: Duration?

    private let lock = NSLock()
    private var _callCount = 0
    var callCount: Int { lock.withLock { _callCount } }

    init(tokensPerCharacter: Double = 0.25) {
        self.tokensPerCharacter = tokensPerCharacter
    }

    func countTokens(in text: String) async throws -> Int {
        lock.withLock { _callCount += 1 }
        if let delay = perCallDelay {
            try await Task.sleep(for: delay)
        }
        if let err = injectedFailure { throw err }
        if let exact = overrideCounts[text] { return exact }
        return max(1, Int((Double(text.count) * tokensPerCharacter).rounded(.up)))
    }
}
