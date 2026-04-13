import Foundation
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
        let url = DocumentTestHelpers.makeTempFile(name: "hello.txt", content: "Hello, world!")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "Hello, world!")
        #expect(result.filename == "hello.txt")
        #expect(result.fileType == "txt")
    }

    @Test func extractMarkdown() async throws {
        let url = DocumentTestHelpers.makeTempFile(
            name: "readme.md", content: "# Title\nSome **bold** text."
        )
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "# Title\nSome **bold** text.")
        #expect(result.fileType == "md")
    }

    @Test func extractCSV() async throws {
        let url = DocumentTestHelpers.makeTempFile(name: "data.csv", content: "a,b,c\n1,2,3")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == "a,b,c\n1,2,3")
        #expect(result.fileType == "csv")
    }

    @Test func extractJSON() async throws {
        let content = "{\"key\": \"value\"}"
        let url = DocumentTestHelpers.makeTempFile(name: "config.json", content: content)
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text == content)
        #expect(result.fileType == "json")
    }

    // MARK: - Truncation

    @Test func truncatesAtLimit() async throws {
        let longText = String(repeating: "A", count: 33_000)
        let url = DocumentTestHelpers.makeTempFile(name: "long.txt", content: longText)
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text.count < longText.count)
        #expect(result.text.hasSuffix("[... truncated at 32K characters]"))
    }

    // MARK: - Error cases

    @Test func unsupportedFormatThrows() async {
        let url = DocumentTestHelpers.makeTempFile(name: "file.xyz", content: "data")
        let extractor = DocumentExtractor()
        await #expect(throws: AppError.self) {
            try await extractor.extract(from: url)
        }
    }

    @Test func emptyFileThrows() async {
        let url = DocumentTestHelpers.makeTempFile(name: "empty.txt", content: "")
        let extractor = DocumentExtractor()
        await #expect(throws: AppError.self) {
            try await extractor.extract(from: url)
        }
    }

    // MARK: - Filename and fileType derivation

    @Test func filenameAndTypeFromURL() async throws {
        let url = DocumentTestHelpers.makeTempFile(name: "script.py", content: "print('hi')")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.filename == "script.py")
        #expect(result.fileType == "py")
    }

    // MARK: - PDF extraction

    @Test func extractPDF() async throws {
        let url = DocumentTestHelpers.makeTempPDF(text: "Hello from PDF")
        let extractor = DocumentExtractor()
        let result = try await extractor.extract(from: url)
        #expect(result.text.contains("Hello from PDF"))
        #expect(result.fileType == "pdf")
    }
}
