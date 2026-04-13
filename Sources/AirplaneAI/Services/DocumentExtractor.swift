import Foundation
import PDFKit

/// Extracts plain text from dropped document files (on-device, no network).
public struct DocumentExtractor: DocumentExtracting, Sendable {
    /// Maximum characters before truncation.
    private static let maxCharacters = 32_768
    private static let truncationMarker = "\n\n[... truncated at 32K characters]"

    public init() {}

    public func extract(from url: URL) async throws -> DocumentExtraction {
        let filename = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let raw = try await extractRaw(from: url, ext: ext)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw AppError.generationFailed(
                summary: "No text extracted from \(filename)"
            )
        }
        return DocumentExtraction(
            text: truncateIfNeeded(trimmed),
            filename: filename,
            fileType: ext
        )
    }
}

// MARK: - Private Helpers

extension DocumentExtractor {
    private func extractRaw(from url: URL, ext: String) async throws -> String {
        if SupportedFormats.isPDF(ext) {
            return try extractPDF(from: url)
        } else if SupportedFormats.isTextutil(ext) {
            return try await runTextutil(on: url)
        } else if SupportedFormats.isPlainText(ext) {
            return try String(contentsOf: url, encoding: .utf8)
        }
        throw AppError.generationFailed(summary: "Unsupported file type: .\(ext)")
    }

    private func extractPDF(from url: URL) throws -> String {
        guard let doc = PDFDocument(url: url) else {
            throw AppError.generationFailed(summary: "Cannot open PDF")
        }
        return doc.string ?? ""
    }

    private func truncateIfNeeded(_ text: String) -> String {
        guard text.count > Self.maxCharacters else { return text }
        let end = text.index(text.startIndex, offsetBy: Self.maxCharacters)
        return String(text[..<end]) + Self.truncationMarker
    }
}
