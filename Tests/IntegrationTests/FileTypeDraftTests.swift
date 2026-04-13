import Foundation
import AppKit
import Testing
@testable import AirplaneAI

/// E2E tests: addFileDraft with REAL extractors for every supported file type.
/// Verifies the draft reaches .ready with correct filename, fileType, and
/// non-empty extracted text — or .error for genuinely unreadable files.
@MainActor
@Suite("File-type draft e2e")
struct FileTypeDraftTests {
    // Uses real ImageAnalyzer + DocumentExtractor — no mocks.
    private func makeController() -> ChatController {
        ChatController(
            state: AppState(),
            engine: MockInferenceEngine(),
            store: MockConversationStore(),
            contextManager: ContextManager(maxContextTokens: 8192),
            tokenCounter: MockTokenCounter(),
            systemPrompt: "test"
        )
    }

    private func waitForReady(_ draft: DraftAttachment) async {
        for _ in 0..<200 {
            if case .parsing = draft.state {} else { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    // MARK: - Images (thumbnail + OCR via Vision)

    @Test func pngImageProducesThumbnail() async {
        let c = makeController()
        let url = writeTempImage(name: "test.png", format: .png)
        c.addFileDraft(url: url)
        #expect(c.draftAttachments.count == 1)
        #expect(c.draftAttachments[0].thumbnail != nil)
        #expect(c.draftAttachments[0].fileType == "image")
        await waitForReady(c.draftAttachments[0])
        assertReady(c.draftAttachments[0])
    }

    @Test func jpegImageProducesThumbnail() async {
        let c = makeController()
        let url = writeTempImage(name: "test.jpg", format: .jpeg)
        c.addFileDraft(url: url)
        #expect(c.draftAttachments[0].thumbnail != nil)
        await waitForReady(c.draftAttachments[0])
        assertReady(c.draftAttachments[0])
    }

    // MARK: - Plain text formats (direct read)

    @Test func txtFileReady() async {
        let c = makeController()
        let url = writeTempText("test.txt", "Hello world")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.txt", fileType: "txt")
    }

    @Test func markdownFileReady() async {
        let c = makeController()
        let url = writeTempText("test.md", "# Heading\nParagraph")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.md", fileType: "md")
    }

    @Test func csvFileReady() async {
        let c = makeController()
        let url = writeTempText("test.csv", "name,age\nAlice,30")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.csv", fileType: "csv")
    }

    @Test func jsonFileReady() async {
        let c = makeController()
        let url = writeTempText("test.json", "{\"key\": \"value\"}")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.json", fileType: "json")
    }

    @Test func htmlFileReady() async {
        let c = makeController()
        let url = writeTempText("test.html", "<html><body>Hi</body></html>")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.html", fileType: "html")
    }

    @Test func yamlFileReady() async {
        let c = makeController()
        let url = writeTempText("test.yaml", "key: value")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.yaml", fileType: "yaml")
    }

    @Test func pythonFileReady() async {
        let c = makeController()
        let url = writeTempText("test.py", "print('hello')")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.py", fileType: "py")
    }

    @Test func swiftFileReady() async {
        let c = makeController()
        let url = writeTempText("test.swift", "let x = 1")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.swift", fileType: "swift")
    }

    @Test func shellFileReady() async {
        let c = makeController()
        let url = writeTempText("test.sh", "#!/bin/bash\necho hi")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.sh", fileType: "sh")
    }

    @Test func xmlFileReady() async {
        let c = makeController()
        let url = writeTempText("test.xml", "<root><item>data</item></root>")
        c.addFileDraft(url: url)
        await waitForReady(c.draftAttachments[0])
        assertReadyDoc(c.draftAttachments[0], filename: "test.xml", fileType: "xml")
    }

    // MARK: - Unknown extension — fallback to plain text

    @Test func unknownExtensionFallsBackToPlainText() async {
        let c = makeController()
        let url = writeTempText("e2e_data_\(UUID().uuidString).xyz", "unknown format content")
        c.addFileDraft(url: url)
        #expect(c.draftAttachments.count == 1)
        await waitForReady(c.draftAttachments[0])
        assertReady(c.draftAttachments[0])
        if let att = c.draftAttachments[0].attachment {
            #expect(att.extractedText.contains("unknown format content"))
        }
    }

    // MARK: - Binary file — error state

    @Test func binaryFileShowsError() async {
        let c = makeController()
        let url = writeTempBinary("blob.dat")
        c.addFileDraft(url: url)
        #expect(c.draftAttachments.count == 1)
        await waitForReady(c.draftAttachments[0])
        if case .error = c.draftAttachments[0].state {} else {
            Issue.record("Expected .error for binary file, got \(c.draftAttachments[0].state)")
        }
    }

    // MARK: - Helpers

    private func assertReady(_ draft: DraftAttachment) {
        if case .ready = draft.state {} else {
            Issue.record("Expected .ready, got \(draft.state)")
        }
        #expect(draft.attachment != nil)
    }

    private func assertReadyDoc(_ draft: DraftAttachment, filename: String, fileType: String) {
        assertReady(draft)
        #expect(draft.filename == filename)
        #expect(draft.fileType == fileType)
        if let att = draft.attachment {
            #expect(!att.extractedText.isEmpty)
        }
    }

    private func writeTempImage(name: String, format: NSBitmapImageRep.FileType) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let img = NSImage(size: NSSize(width: 50, height: 50))
        img.lockFocus()
        NSColor.blue.drawSwatch(in: NSRect(x: 0, y: 0, width: 50, height: 50))
        img.unlockFocus()
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: format, properties: [:]) {
            try? data.write(to: url)
        }
        return url
    }

    private func writeTempText(_ name: String, _ content: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func writeTempBinary(_ name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? Data([0xFF, 0xFE, 0x00, 0x01, 0x80, 0x81]).write(to: url)
        return url
    }
}
