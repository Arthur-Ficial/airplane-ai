import Foundation
import Testing
@testable import AirplaneAI

@Suite("Attachment prompt formatting")
struct AttachmentFormattingTests {
    @Test func messageWithNoAttachmentsUnchanged() {
        let msg = ChatMessage(role: .user, content: "Hello")
        let materialized = msg.materializedContent
        #expect(materialized == "Hello")
    }

    @Test func imageAttachmentPrepended() {
        let msg = ChatMessage(
            role: .user,
            content: "What's in this image?",
            attachments: [.image(data: Data(), extractedText: "OCR:\n  Hello World\nLABELS: text\nDOC: no")]
        )
        let result = msg.materializedContent
        #expect(result.contains("CONTEXT: image"))
        #expect(result.contains("OCR:\n  Hello World"))
        #expect(result.contains("What's in this image?"))
        // Attachment text comes before user text.
        let contextIdx = result.range(of: "CONTEXT: image")!.lowerBound
        let userIdx = result.range(of: "What's in this image?")!.lowerBound
        #expect(contextIdx < userIdx)
    }

    @Test func documentAttachmentPrepended() {
        let msg = ChatMessage(
            role: .user,
            content: "Summarize this",
            attachments: [.document(text: "Page 1 text", filename: "report.pdf", fileType: "pdf")]
        )
        let result = msg.materializedContent
        #expect(result.contains("CONTEXT: document (report.pdf)"))
        #expect(result.contains("Page 1 text"))
        #expect(result.contains("Summarize this"))
    }

    @Test func audioAttachmentPrepended() {
        let msg = ChatMessage(
            role: .user,
            content: "Respond to this",
            attachments: [.audio(transcript: "Hello from speech")]
        )
        let result = msg.materializedContent
        #expect(result.contains("CONTEXT: speech transcript"))
        #expect(result.contains("Hello from speech"))
    }

    @Test func multipleAttachmentsCombined() {
        let msg = ChatMessage(
            role: .user,
            content: "Check these",
            attachments: [
                .image(data: Data(), extractedText: "OCR: cat photo"),
                .document(text: "Report content", filename: "r.txt", fileType: "txt"),
            ]
        )
        let result = msg.materializedContent
        #expect(result.contains("CONTEXT: image"))
        #expect(result.contains("CONTEXT: document (r.txt)"))
        #expect(result.contains("Check these"))
    }

    @Test func contextWindowAccountsForAttachmentTokens() {
        let plain = ChatMessage(role: .user, content: "hi")
        let withAttachment = ChatMessage(
            role: .user, content: "hi",
            attachments: [.document(text: String(repeating: "word ", count: 200), filename: "f.txt", fileType: "txt")]
        )
        let plainTokens = plain.estimatedTotalTokens
        let attachTokens = withAttachment.estimatedTotalTokens
        #expect(attachTokens > plainTokens)
    }
}
