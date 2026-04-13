import Foundation
import AppKit
import Testing
@testable import AirplaneAI

/// E2E tests for attachment processing pipelines (image + document).
@Suite("Attachment flow e2e")
struct AttachmentFlowTests {
    @Test func imageAnalyzerProducesStructuredText() async throws {
        // Create a simple image with text drawn on it.
        let image = NSImage(size: NSSize(width: 200, height: 50))
        image.lockFocus()
        let str = "Hello World" as NSString
        str.draw(at: NSPoint(x: 10, y: 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black,
        ])
        image.unlockFocus()

        let analyzer = ImageAnalyzer()
        let text = try await analyzer.analyze(image)
        #expect(text.contains("CONTEXT: image"))
        #expect(text.contains("OCR:"))
    }

    @Test func documentExtractorReadsPlainText() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("e2e-test.txt")
        try "Hello from e2e test".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: tmp)
        #expect(result.text.contains("Hello from e2e test"))
        #expect(result.filename == "e2e-test.txt")
        #expect(result.fileType == "txt")
    }

    @Test func documentExtractorReadsMarkdown() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test.md")
        try "# Title\n\nParagraph text".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: tmp)
        #expect(result.text.contains("# Title"))
        #expect(result.fileType == "md")
    }

    @Test func materializedContentIncludesAttachmentText() {
        let msg = ChatMessage(
            role: .user,
            content: "What does this say?",
            attachments: [
                .image(data: Data(), extractedText: "CONTEXT: image\nOCR:\n  Hello\nLABELS: text\nDOC: no"),
            ]
        )
        let materialized = msg.materializedContent
        #expect(materialized.contains("CONTEXT: image"))
        #expect(materialized.contains("What does this say?"))
    }

    @Test func attachmentTokenCountIncludedInEstimate() {
        let plain = ChatMessage(role: .user, content: "hi")
        let rich = ChatMessage(role: .user, content: "hi", attachments: [
            .document(text: String(repeating: "x", count: 1000), filename: "f.txt", fileType: "txt"),
        ])
        #expect(rich.estimatedTotalTokens > plain.estimatedTotalTokens)
    }
}
