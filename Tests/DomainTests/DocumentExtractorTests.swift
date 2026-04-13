import Foundation
import PDFKit
import Testing
@testable import AirplaneAI

@Suite("DocumentExtractor")
struct DocumentExtractorTests {
    // MARK: - Mock tests

    @Test func mockReturnsExpectedExtraction() async throws {
        let mock = MockDocumentExtractor()
        let result = try await mock.extract(from: URL(fileURLWithPath: "/tmp/test.txt"))
        #expect(result.text == "mock text")
        #expect(result.filename == "test.txt")
        #expect(result.fileType == "txt")
    }

    @Test func mockThrowsWhenConfigured() async {
        let mock = MockDocumentExtractor()
        mock.shouldThrow = true
        await #expect(throws: AppError.self) {
            try await mock.extract(from: URL(fileURLWithPath: "/tmp/test.txt"))
        }
    }

    // MARK: - Plain text extraction

    @Test func extractPlainText() async throws {
        let url = makeTempFile(name: "hello.txt", content: "Hello, world!")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "Hello, world!")
        #expect(result.filename == "hello.txt")
        #expect(result.fileType == "txt")
    }

    // MARK: - Markdown extraction

    @Test func extractMarkdown() async throws {
        let url = makeTempFile(name: "readme.md", content: "# Title\nSome **bold** text.")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "# Title\nSome **bold** text.")
        #expect(result.fileType == "md")
    }

    // MARK: - CSV extraction

    @Test func extractCSV() async throws {
        let url = makeTempFile(name: "data.csv", content: "a,b,c\n1,2,3")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "a,b,c\n1,2,3")
        #expect(result.fileType == "csv")
    }

    // MARK: - JSON extraction

    @Test func extractJSON() async throws {
        let content = "{\"key\": \"value\"}"
        let url = makeTempFile(name: "config.json", content: content)
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == content)
        #expect(result.fileType == "json")
    }

    // MARK: - Truncation

    @Test func truncatesAtLimit() async throws {
        let longText = String(repeating: "A", count: 33_000)
        let url = makeTempFile(name: "long.txt", content: longText)
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text.count < longText.count)
        #expect(result.text.hasSuffix("[... truncated at 32K characters]"))
    }

    // MARK: - Unsupported format

    @Test func unsupportedFormatThrows() async {
        let url = makeTempFile(name: "file.xyz", content: "data")
        let extractor = DocumentExtractor()
        await #expect(throws: AppError.self) {
            try await extractor.extract(from: url)
        }
    }

    // MARK: - Empty file

    @Test func emptyFileThrows() async {
        let url = makeTempFile(name: "empty.txt", content: "")
        let extractor = DocumentExtractor()
        await #expect(throws: AppError.self) {
            try await extractor.extract(from: url)
        }
    }

    // MARK: - Filename and fileType derivation

    @Test func filenameAndTypeFromURL() async throws {
        let url = makeTempFile(name: "script.py", content: "print('hi')")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.filename == "script.py")
        #expect(result.fileType == "py")
    }

    // MARK: - PDF extraction (programmatic)

    @Test func extractPDF() async throws {
        let url = makeTempPDF(text: "Hello from PDF")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text.contains("Hello from PDF"))
        #expect(result.fileType == "pdf")
    }

    // MARK: - Helpers

    private func makeTempFile(name: String, content: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeTempPDF(text: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("test.pdf")
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var rect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: consumer, mediaBox: &rect, nil)!
        context.beginPage(mediaBox: &rect)
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: 72, y: 720)
        CTLineDraw(line, context)
        context.endPage()
        context.closePDF()
        try! data.write(to: url, atomically: true)
        return url
    }
}
