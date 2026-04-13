import Foundation
import AppKit
import Testing
@testable import AirplaneAI

@MainActor
@Suite("Attachment drafts")
struct AttachmentDraftTests {
    private func makeController(
        imageAnalyzer: MockImageAnalyzer = MockImageAnalyzer(),
        documentExtractor: MockDocumentExtractor = MockDocumentExtractor()
    ) -> (ChatController, AppState) {
        let state = AppState()
        let controller = ChatController(
            state: state,
            engine: MockInferenceEngine(),
            store: MockConversationStore(),
            contextManager: ContextManager(maxContextTokens: 8192),
            tokenCounter: MockTokenCounter(),
            systemPrompt: "test",
            imageAnalyzer: imageAnalyzer,
            documentExtractor: documentExtractor
        )
        return (controller, state)
    }

    private func makeTestImage() -> NSImage {
        let img = NSImage(size: NSSize(width: 10, height: 10))
        img.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 10, height: 10))
        img.unlockFocus()
        return img
    }

    // MARK: - Image draft thumbnails

    @Test func addImageDraftSetsThumbnail() async throws {
        let (controller, _) = makeController()
        let image = makeTestImage()
        controller.addImageDraft(image)
        #expect(controller.draftAttachments.count == 1)
        #expect(controller.draftAttachments[0].thumbnail != nil)
        #expect(controller.draftAttachments[0].fileType == "image")
    }

    @Test func addImageDraftTransitionsToReady() async throws {
        let (controller, _) = makeController()
        controller.addImageDraft(makeTestImage())
        // Wait for async analysis to complete.
        for _ in 0..<50 {
            if case .ready = controller.draftAttachments.first?.state ?? .parsing { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let draft = controller.draftAttachments[0]
        if case .ready = draft.state {} else {
            Issue.record("Expected .ready, got \(draft.state)")
        }
        #expect(draft.attachment != nil)
    }

    @Test func addImageDraftErrorSetsErrorState() async throws {
        let analyzer = MockImageAnalyzer()
        analyzer.shouldThrow = true
        let (controller, _) = makeController(imageAnalyzer: analyzer)
        controller.addImageDraft(makeTestImage())
        for _ in 0..<50 {
            if case .error = controller.draftAttachments.first?.state ?? .parsing { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        if case .error = controller.draftAttachments[0].state {} else {
            Issue.record("Expected .error state")
        }
    }

    // MARK: - File draft for images

    @Test func addFileDraftForImageSetsThumbnail() async throws {
        let (controller, _) = makeController()
        let url = createTempImage()
        controller.addFileDraft(url: url)
        #expect(controller.draftAttachments.count == 1)
        #expect(controller.draftAttachments[0].thumbnail != nil)
        #expect(controller.draftAttachments[0].filename == url.lastPathComponent)
    }

    // MARK: - File draft for documents

    @Test func addFileDraftForTextCreatesDocDraft() async throws {
        let extractor = MockDocumentExtractor()
        extractor.result = DocumentExtraction(
            text: "hello", filename: "notes.txt", fileType: "txt"
        )
        let (controller, _) = makeController(documentExtractor: extractor)
        let url = createTempFile(name: "notes.txt", content: "hello")
        controller.addFileDraft(url: url)
        #expect(controller.draftAttachments.count == 1)
        #expect(controller.draftAttachments[0].thumbnail == nil)
        #expect(controller.draftAttachments[0].fileType == "txt")
    }

    // MARK: - Unsupported file types — must not silently drop

    @Test func addFileDraftForUnknownExtensionTriesPlainText() async throws {
        let (controller, _) = makeController()
        let url = createTempFile(name: "data.xyz", content: "some data content")
        controller.addFileDraft(url: url)
        // Must NOT silently drop — should create a draft.
        #expect(controller.draftAttachments.count == 1)
        let draft = controller.draftAttachments[0]
        #expect(draft.filename == "data.xyz")
        // Wait for processing.
        for _ in 0..<50 {
            if case .parsing = draft.state {} else { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        // Should be ready with text content.
        if case .ready = draft.state {} else {
            Issue.record("Expected .ready for plain-text fallback, got \(draft.state)")
        }
    }

    @Test func addFileDraftForBinaryUnknownExtensionShowsError() async throws {
        let (controller, _) = makeController()
        // Create a file with non-UTF8 binary content.
        let url = createTempBinaryFile(name: "blob.dat")
        controller.addFileDraft(url: url)
        #expect(controller.draftAttachments.count == 1)
        let draft = controller.draftAttachments[0]
        for _ in 0..<50 {
            if case .parsing = draft.state {} else { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        if case .error = draft.state {} else {
            Issue.record("Expected .error for unreadable binary, got \(draft.state)")
        }
    }

    // MARK: - Token counting after extraction

    @Test func addImageDraftCountsTokensAfterExtraction() async throws {
        let (controller, _) = makeController()
        controller.addImageDraft(makeTestImage())
        for _ in 0..<100 {
            if controller.draftAttachments.first?.tokenCount != nil { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let draft = controller.draftAttachments[0]
        #expect(draft.tokenCount != nil)
        #expect(draft.tokenCount! > 0)
    }

    @Test func addFileDraftCountsTokensAfterExtraction() async throws {
        let extractor = MockDocumentExtractor()
        extractor.result = DocumentExtraction(text: "hello world", filename: "f.txt", fileType: "txt")
        let (controller, _) = makeController(documentExtractor: extractor)
        let url = createTempFile(name: "count_test.txt", content: "hello world")
        controller.addFileDraft(url: url)
        for _ in 0..<100 {
            if controller.draftAttachments.first?.tokenCount != nil { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(controller.draftAttachments[0].tokenCount != nil)
        #expect(controller.draftAttachments[0].tokenCount! > 0)
    }

    // MARK: - Attachment limits

    @Test func rejectsAttachmentExceedingTokenBudget() async throws {
        // MockTokenCounter: 0.25 tok/char. Budget = 8192 - 512 - 128 = 7552.
        // Configure mock to return 40000-char text → 10000 tokens > 7552.
        let extractor = MockDocumentExtractor()
        extractor.result = DocumentExtraction(
            text: String(repeating: "x", count: 40_000),
            filename: "huge.txt", fileType: "txt"
        )
        let (controller, _) = makeController(documentExtractor: extractor)
        let url = createTempFile(name: "huge.txt", content: "placeholder")
        controller.addFileDraft(url: url)
        for _ in 0..<100 {
            if case .parsing = controller.draftAttachments.first?.state ?? .parsing {} else { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        if case .error = controller.draftAttachments[0].state {} else {
            Issue.record("Expected .error for oversized attachment, got \(controller.draftAttachments[0].state)")
        }
    }

    @Test func rejectsEleventhAttachment() async throws {
        let (controller, state) = makeController()
        for i in 0..<10 {
            controller.addImageDraft(makeTestImage())
            #expect(controller.draftAttachments.count == i + 1)
        }
        // 11th should be rejected
        controller.addImageDraft(makeTestImage())
        #expect(controller.draftAttachments.count == 10)
        #expect(state.lastError == .tooManyAttachments(limit: 10))
    }

    // MARK: - Remove draft

    @Test func removeDraftRemovesFromList() {
        let (controller, _) = makeController()
        controller.addImageDraft(makeTestImage())
        #expect(controller.draftAttachments.count == 1)
        controller.removeDraft(controller.draftAttachments[0])
        #expect(controller.draftAttachments.isEmpty)
    }

    // MARK: - Send clears drafts

    @Test func sendClearsDraftAttachments() async throws {
        let (controller, _) = makeController()
        controller.addImageDraft(makeTestImage())
        // Wait for ready.
        for _ in 0..<50 {
            if case .ready = controller.draftAttachments.first?.state ?? .parsing { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        await controller.send("test with attachment")
        #expect(controller.draftAttachments.isEmpty)
    }

    // MARK: - Helpers

    private func createTempImage() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).png")
        let img = makeTestImage()
        if let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url)
        }
        return url
    }

    private func createTempFile(name: String, content: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func createTempBinaryFile(name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        // Write bytes that are invalid UTF-8.
        let bytes: [UInt8] = [0xFF, 0xFE, 0x00, 0x01, 0x80, 0x81, 0xC0, 0xC1]
        try? Data(bytes).write(to: url)
        return url
    }
}
