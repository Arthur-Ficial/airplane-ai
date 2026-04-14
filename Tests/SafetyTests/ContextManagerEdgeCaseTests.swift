import Foundation
import Testing
@testable import AirplaneAI

@Suite("ContextManager edge cases")
struct ContextManagerEdgeCaseTests {

    @Test func emptyConversationReturnsEmpty() async throws {
        let tc = MockTokenCounter()
        let cm = ContextManager(maxContextTokens: 8192)
        let kept = try await cm.fitToContext(
            systemPrompt: "You are helpful.", messages: [], tokenCounter: tc
        )
        #expect(kept.isEmpty)
    }

    @Test func singleUserMessageFits() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let msg = ChatMessage(role: .user, content: "Hello")
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
        #expect(kept.first?.content == "Hello")
    }

    @Test func singleUserMessageTooLargeThrows() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(
            maxContextTokens: 100, reservedForResponse: 10, templateOverheadTokens: 10
        )
        // Budget = 80. System "sys" = 3. Newest = 200. 203 > 80.
        let msg = ChatMessage(role: .user, content: String(repeating: "x", count: 200))
        do {
            _ = try await cm.fitToContext(
                systemPrompt: "sys", messages: [msg], tokenCounter: tc
            )
            Issue.record("Expected inputTooLarge")
        } catch AppError.inputTooLarge {
            // expected
        }
    }

    @Test func zeroLengthMessageContent() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let msg = ChatMessage(role: .user, content: "")
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: [msg], tokenCounter: tc
        )
        // Empty string → max(1, 0) = 1 token. Fits easily.
        #expect(kept.count == 1)
    }

    @Test func unicodeEmojiSequences() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let emoji = "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"
        let msg = ChatMessage(role: .user, content: "Tell me about \(emoji)")
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
        #expect(kept.first!.content.contains(emoji))
    }

    @Test func unicodeMixedScripts() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let mixed = "مرحبا 你好 こんにちは"
        let msg = ChatMessage(role: .user, content: mixed)
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
        #expect(kept.first!.content == mixed)
    }

    @Test func budgetExactlyEqualsFits() async throws {
        let tc = MockTokenCounter()
        tc.overrideCounts = ["system": 10, "hello": 40]
        let cm = ContextManager(
            maxContextTokens: 100, reservedForResponse: 25, templateOverheadTokens: 25
        )
        // Budget = 50. sysTokens=10 + newestTokens=40 = 50. Exactly fits.
        let msg = ChatMessage(role: .user, content: "hello")
        let kept = try await cm.fitToContext(
            systemPrompt: "system", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
    }

    @Test func budgetExactlyExceededByOneThrows() async throws {
        let tc = MockTokenCounter()
        tc.overrideCounts = ["system": 10, "hello": 41]
        let cm = ContextManager(
            maxContextTokens: 100, reservedForResponse: 25, templateOverheadTokens: 25
        )
        // Budget = 50. sysTokens=10 + newestTokens=41 = 51 > 50.
        let msg = ChatMessage(role: .user, content: "hello")
        do {
            _ = try await cm.fitToContext(
                systemPrompt: "system", messages: [msg], tokenCounter: tc
            )
            Issue.record("Expected inputTooLarge")
        } catch AppError.inputTooLarge {
            // expected
        }
    }

    @Test func attachmentTextIncludedInCount() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(
            maxContextTokens: 200, reservedForResponse: 20, templateOverheadTokens: 20
        )
        // Budget = 160. System "s" = 1. Document attachment adds substantial text.
        let doc = Attachment.document(
            text: String(repeating: "d", count: 100),
            filename: "f.txt", fileType: "txt"
        )
        let msg = ChatMessage(role: .user, content: "hi", attachments: [doc])
        // materializedContent is large because it includes attachment text.
        let kept = try await cm.fitToContext(
            systemPrompt: "s", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
    }

    @Test func veryLongSingleMessage() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.01)
        let cm = ContextManager(maxContextTokens: 100_000)
        let msg = ChatMessage(
            role: .user, content: String(repeating: "a", count: 100_000)
        )
        let kept = try await cm.fitToContext(
            systemPrompt: "s", messages: [msg], tokenCounter: tc
        )
        #expect(kept.count == 1)
    }

    @Test func assistantLastMessageBypassesTrimming() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 0.25)
        let cm = ContextManager(maxContextTokens: 8192)
        let msgs = [
            ChatMessage(role: .user, content: "hi"),
            ChatMessage(role: .assistant, content: "hello"),
        ]
        // Last message is assistant → guard returns early with all messages.
        let kept = try await cm.fitToContext(
            systemPrompt: "sys", messages: msgs, tokenCounter: tc
        )
        #expect(kept.count == 2)
    }

    @Test func trimPreservesChronologicalOrder() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(
            maxContextTokens: 100, reservedForResponse: 10, templateOverheadTokens: 10
        )
        // Budget = 80. System "s" = 1. Each msg = 10 chars = 10 tokens.
        // 20 messages alternate user/assistant. With sys+newest = 11,
        // remaining budget 69 → fits 6 more. Total kept = 7 out of 20.
        var msgs: [ChatMessage] = []
        for i in 0..<19 {
            msgs.append(ChatMessage(
                role: i % 2 == 0 ? .user : .assistant,
                content: String(repeating: Character(String(i % 10)), count: 10)
            ))
        }
        msgs.append(ChatMessage(role: .user, content: "finalquest"))
        let kept = try await cm.fitToContext(
            systemPrompt: "s", messages: msgs, tokenCounter: tc
        )
        #expect(kept.last?.content == "finalquest")
        #expect(kept.count < msgs.count)
        // Verify chronological order preserved: each message's createdAt >= previous.
        for i in 1..<kept.count {
            #expect(kept[i].createdAt >= kept[i - 1].createdAt)
        }
    }
}
