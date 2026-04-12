import Foundation

// Spec §12.3: system prompt + NEWEST user message are inviolable.
// Trim oldest history first. If newest alone exceeds budget → throw.
public struct ContextManager: Sendable {
    public let maxContextTokens: Int
    public let reservedForResponse: Int
    public let templateOverheadTokens: Int

    public init(maxContextTokens: Int, reservedForResponse: Int = 512, templateOverheadTokens: Int = 128) {
        self.maxContextTokens = maxContextTokens
        self.reservedForResponse = reservedForResponse
        self.templateOverheadTokens = templateOverheadTokens
    }

    public var inputBudget: Int {
        max(0, maxContextTokens - reservedForResponse - templateOverheadTokens)
    }

    public func fitToContext(
        systemPrompt: String,
        messages: [ChatMessage],
        tokenCounter: any TokenCounter
    ) async throws -> [ChatMessage] {
        let budget = inputBudget
        guard let newest = messages.last, newest.role == .user else {
            // No user turn yet — nothing to validate.
            return messages
        }
        let sysTokens = try await tokenCounter.countTokens(in: systemPrompt)
        let newestTokens = try await tokenCounter.countTokens(in: newest.content)
        if sysTokens + newestTokens > budget {
            throw AppError.inputTooLarge(maxTokens: budget)
        }
        // Walk backwards from newest, keep history that fits.
        var kept: [ChatMessage] = [newest]
        var used = sysTokens + newestTokens
        let history = messages.dropLast()
        for msg in history.reversed() {
            let t = try await tokenCounter.countTokens(in: msg.content)
            if used + t > budget { break }
            kept.insert(msg, at: 0)
            used += t
        }
        return kept
    }
}
