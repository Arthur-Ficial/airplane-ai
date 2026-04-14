import Foundation
import Testing
@testable import AirplaneAI

@Suite("Image token context accounting")
struct ImageTokenContextTests {
    @Test func imageAttachmentTokensCountInContextBudget() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 500, reservedForResponse: 50, templateOverheadTokens: 50)
        // Budget = 400. System = 3 ("sys").
        // Message with small content but large image extracted text.
        let imageAttachment = Attachment.image(
            data: Data(),
            extractedText: String(repeating: "x", count: 300)
        )
        let msg = ChatMessage(role: .user, content: "look", attachments: [imageAttachment])
        // materializedContent ≈ "CONTEXT: image\n" + 300 chars + "\n\nlook" → well over 300 tokens
        // 3 (sys) + ~318 = ~321 < 400, should fit.
        let kept = try await cm.fitToContext(systemPrompt: "sys", messages: [msg], tokenCounter: tc)
        #expect(kept.count == 1)
    }

    @Test func imageAttachmentExceedingBudgetThrows() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 200, reservedForResponse: 50, templateOverheadTokens: 50)
        // Budget = 100. System = 3.
        let imageAttachment = Attachment.image(
            data: Data(),
            extractedText: String(repeating: "x", count: 200)
        )
        let msg = ChatMessage(role: .user, content: "hi", attachments: [imageAttachment])
        // materializedContent = "CONTEXT: image\n" + 200 chars + "\n\nhi" → ~218 tokens. 3 + 218 > 100.
        do {
            _ = try await cm.fitToContext(systemPrompt: "sys", messages: [msg], tokenCounter: tc)
            Issue.record("expected inputTooLarge")
        } catch AppError.inputTooLarge {
            // expected
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func multipleImagesTrimsOlderMessages() async throws {
        let tc = MockTokenCounter(tokensPerCharacter: 1.0)
        let cm = ContextManager(maxContextTokens: 300, reservedForResponse: 30, templateOverheadTokens: 20)
        // Budget = 250. System = 3.
        let img = Attachment.image(data: Data(), extractedText: String(repeating: "i", count: 50))
        let old1 = ChatMessage(role: .user, content: "old1", attachments: [img])
        let old2 = ChatMessage(role: .assistant, content: String(repeating: "r", count: 80))
        let old3 = ChatMessage(role: .user, content: String(repeating: "q", count: 100))
        let newest = ChatMessage(role: .user, content: "new", attachments: [img])
        let msgs = [old1, old2, old3, newest]
        // Total tokens would exceed budget → should trim older messages.
        let kept = try await cm.fitToContext(systemPrompt: "sys", messages: msgs, tokenCounter: tc)
        #expect(kept.last?.content == "new")
        #expect(kept.count < msgs.count)
    }
}
