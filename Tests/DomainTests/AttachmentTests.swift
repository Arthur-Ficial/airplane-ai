import Foundation
import Testing
@testable import AirplaneAI

@Suite("Attachment")
struct AttachmentTests {
    @Test func imageRoundTripCodable() throws {
        let data = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header stub
        let a = Attachment.image(data: data, extractedText: "OCR: hello")
        let encoded = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(Attachment.self, from: encoded)
        #expect(a == decoded)
    }

    @Test func documentRoundTripCodable() throws {
        let a = Attachment.document(text: "Page 1 content", filename: "report.pdf", fileType: "pdf")
        let encoded = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(Attachment.self, from: encoded)
        #expect(a == decoded)
    }

    @Test func audioRoundTripCodable() throws {
        let a = Attachment.audio(transcript: "Hello world")
        let encoded = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(Attachment.self, from: encoded)
        #expect(a == decoded)
    }

    @Test func chatMessageWithAttachments() throws {
        let msg = ChatMessage(
            role: .user,
            content: "Check this image",
            attachments: [
                .image(data: Data([0xFF]), extractedText: "OCR: test"),
                .document(text: "doc text", filename: "f.txt", fileType: "txt"),
            ]
        )
        #expect(msg.attachments.count == 2)
        let encoded = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: encoded)
        #expect(decoded.attachments.count == 2)
    }

    @Test func chatMessageDefaultsToNoAttachments() {
        let msg = ChatMessage(role: .user, content: "plain text")
        #expect(msg.attachments.isEmpty)
    }

    @Test func estimatedTokenCountForImage() {
        let a = Attachment.image(data: Data(), extractedText: "line1\nline2\nline3")
        #expect(a.estimatedTokenCount > 0)
    }

    @Test func estimatedTokenCountForDocument() {
        let text = String(repeating: "word ", count: 100)
        let a = Attachment.document(text: text, filename: "f.txt", fileType: "txt")
        #expect(a.estimatedTokenCount > 0)
    }
}
