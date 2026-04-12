import Foundation
import Testing
@testable import AirplaneAI

@Suite("ContextManager stress")
struct ContextManagerStressTests {
    @Test func trims1000SmallMessagesInBudget() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 2048, reservedForResponse: 256, templateOverheadTokens: 64)
        var msgs: [ChatMessage] = []
        for i in 0..<1000 {
            msgs.append(ChatMessage(
                role: i % 2 == 0 ? .user : .assistant,
                content: String(repeating: "w", count: 10)
            ))
        }
        // Last is user to trigger the invariant.
        msgs.append(ChatMessage(role: .user, content: "final question"))
        let kept = try await cm.fitToContext(systemPrompt: "S", messages: msgs, tokenCounter: tc)
        #expect(kept.last?.content == "final question")
        #expect(kept.count <= msgs.count)
    }

    @Test func rejectsSingleGiantNewestMessage() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 500, reservedForResponse: 100, templateOverheadTokens: 50)
        // Budget = 350. System = 1. Newest alone > 500 chars → must throw.
        let newest = ChatMessage(role: .user, content: String(repeating: "x", count: 2000))
        var threw = false
        do { _ = try await cm.fitToContext(systemPrompt: "s", messages: [newest], tokenCounter: tc) }
        catch AppError.inputTooLarge { threw = true } catch {}
        #expect(threw)
    }
}
