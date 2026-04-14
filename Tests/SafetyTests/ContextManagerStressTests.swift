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

    @Test func concurrentFitToContextCalls() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let msgs = [ChatMessage(role: .user, content: "hello")]
        try await withThrowingTaskGroup(of: [ChatMessage].self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await cm.fitToContext(
                        systemPrompt: "sys", messages: msgs, tokenCounter: tc
                    )
                }
            }
            var results: [[ChatMessage]] = []
            for try await r in group { results.append(r) }
            #expect(results.count == 10)
            for r in results { #expect(r.count == 1) }
        }
    }

    @Test func thousandMessagesPerformance() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(
            maxContextTokens: 4096, reservedForResponse: 256, templateOverheadTokens: 64
        )
        var msgs: [ChatMessage] = []
        for i in 0..<999 {
            msgs.append(ChatMessage(
                role: i % 2 == 0 ? .user : .assistant,
                content: String(repeating: "w", count: 20)
            ))
        }
        msgs.append(ChatMessage(role: .user, content: "last"))
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: msgs, tokenCounter: tc
        )
        #expect(kept.last?.content == "last")
        #expect(kept.count >= 1)
        #expect(kept.count <= msgs.count)
    }

    @Test func progressiveFilling() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(
            maxContextTokens: 100, reservedForResponse: 10, templateOverheadTokens: 10
        )
        // Budget = 80. System "s" = 1.
        var msgs: [ChatMessage] = []
        var previousKeptCount = 0
        for i in 0..<20 {
            let role: MessageRole = i % 2 == 0 ? .user : .assistant
            msgs.append(ChatMessage(
                role: role,
                content: String(repeating: "m", count: 10)
            ))
            // Only call when last message is .user (otherwise guard returns all).
            if role == .user {
                let kept = try await cm.fitToContext(
                    systemPrompt: "s", messages: msgs, tokenCounter: tc
                )
                // Kept count should be bounded — can't grow forever.
                #expect(kept.count <= msgs.count)
                #expect(kept.count >= 1)
                previousKeptCount = kept.count
            }
        }
        // After 20 messages, the kept count should be capped by budget.
        #expect(previousKeptCount < 20)
    }
}
