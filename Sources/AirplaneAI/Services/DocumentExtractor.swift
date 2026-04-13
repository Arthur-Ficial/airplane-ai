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
        } else if SupportedFormats.isSpreadsheet(ext) {
            return try await extractSpreadsheet(from: url)
        } else if SupportedFormats.isPlainText(ext) {
            return try String(contentsOf: url, encoding: .utf8)
        }
        throw AppError.generationFailed(summary: "Unsupported file type: .\(ext)")
    }

    /// Extract text from .xlsx by unzipping and reading the XML content.
    /// For .xls (legacy binary), falls back to textutil which can handle it.
    private func extractSpreadsheet(from url: URL) async throws -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "xls" {
            // Legacy .xls — textutil can convert it
            return try await runTextutil(on: url)
        }
        // .xlsx is a zip of XML files. Extract shared strings + sheet data.
        return try await extractXlsx(from: url)
    }

    private func extractXlsx(from url: URL) async throws -> String {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlsx_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", url.path, "-d", tmp.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppError.generationFailed(summary: "Cannot unzip xlsx")
        }

        // Read shared strings (cell text values).
        let sharedStringsURL = tmp.appendingPathComponent("xl/sharedStrings.xml")
        var strings: [String] = []
        if let data = try? Data(contentsOf: sharedStringsURL),
           let xml = try? XMLDocument(data: data) {
            let nodes = try xml.nodes(forXPath: "//t")
            strings = nodes.compactMap { $0.stringValue }
        }

        // Read first sheet for structure.
        let sheet1URL = tmp.appendingPathComponent("xl/worksheets/sheet1.xml")
        if let data = try? Data(contentsOf: sheet1URL),
           let xml = try? XMLDocument(data: data) {
            let rows = try xml.nodes(forXPath: "//row")
            var lines: [String] = []
            for row in rows {
                guard let rowEl = row as? XMLElement else { continue }
                let cells = rowEl.children?.compactMap { $0 as? XMLElement } ?? []
                var cellValues: [String] = []
                for cell in cells {
                    let type = cell.attribute(forName: "t")?.stringValue
                    let value = cell.elements(forName: "v").first?.stringValue ?? ""
                    if type == "s", let idx = Int(value), idx < strings.count {
                        cellValues.append(strings[idx])
                    } else {
                        cellValues.append(value)
                    }
                }
                lines.append(cellValues.joined(separator: "\t"))
            }
            return lines.joined(separator: "\n")
        }

        // Fallback: just return shared strings
        return strings.joined(separator: "\n")
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
