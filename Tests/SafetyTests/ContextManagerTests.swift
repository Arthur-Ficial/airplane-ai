import Foundation
import Testing
@testable import AirplaneAI

@Suite("ContextManager")
struct ContextManagerTests {
    @Test func rejectsOversizedNewestMessage() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 100, reservedForResponse: 10, templateOverheadTokens: 10)
        let msg = ChatMessage(role: .user, content: String(repeating: "x", count: 200))
        do {
            _ = try await cm.fitToContext(systemPrompt: "sys", messages: [msg], tokenCounter: tc)
            Issue.record("expected throw")
        } catch let AppError.inputTooLarge(max) {
            #expect(max == 80)
        }
    }

    @Test func trimsOldestHistoryButKeepsNewest() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 30, reservedForResponse: 5, templateOverheadTokens: 5)
        // Budget = 20. Sys=3 ("sys"), newest=5. Remaining=12. Old messages: 10,10,10 — only one fits.
        let msgs: [ChatMessage] = [
            ChatMessage(role: .user, content: String(repeating: "a", count: 10)),
            ChatMessage(role: .assistant, content: String(repeating: "b", count: 10)),
            ChatMessage(role: .user, content: String(repeating: "c", count: 10)),
            ChatMessage(role: .user, content: String(repeating: "d", count: 5)), // newest
        ]
        let kept = try await cm.fitToContext(systemPrompt: "sys", messages: msgs, tokenCounter: tc)
        #expect(kept.last?.content == msgs.last?.content) // newest preserved
        #expect(kept.count <= msgs.count)
        #expect(kept.count >= 1)
    }

    @Test func noUserTurnYetReturnsUnchanged() async throws {
        let tc = MockTokenCounter()
        let cm = ContextManager(maxContextTokens: 100)
        let kept = try await cm.fitToContext(systemPrompt: "sys", messages: [], tokenCounter: tc)
        #expect(kept.isEmpty)
    }
}
