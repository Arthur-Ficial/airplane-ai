import Foundation

public protocol TokenCounter: Sendable {
    func countTokens(in text: String) async throws -> Int
}
