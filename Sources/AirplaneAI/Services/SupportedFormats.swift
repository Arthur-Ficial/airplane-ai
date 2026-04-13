import Foundation
import UniformTypeIdentifiers

/// Defines which file extensions DocumentExtractor can handle.
enum SupportedFormats {
    // Images handled via ImageAnalyzer (Apple Vision)
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "tiff", "heic", "bmp",
    ]

    // PDF handled via PDFKit
    private static let pdfExtensions: Set<String> = ["pdf"]

    // Word/RTF handled via /usr/bin/textutil
    private static let textutilExtensions: Set<String> = [
        "docx", "doc", "rtf", "rtfd",
    ]

    // Spreadsheets — extracted via XML inside the zip archive
    private static let spreadsheetExtensions: Set<String> = [
        "xlsx", "xls",
    ]

    // Plain text read directly via String(contentsOf:)
    private static let plainTextExtensions: Set<String> = [
        "txt", "csv", "json", "xml", "log",
        "yaml", "yml", "toml", "ini", "cfg", "conf",
        "sh", "zsh", "bash", "py", "swift", "js", "ts",
        "html", "css", "md", "markdown",
    ]

    static func isPDF(_ ext: String) -> Bool {
        pdfExtensions.contains(ext)
    }

    static func isTextutil(_ ext: String) -> Bool {
        textutilExtensions.contains(ext)
    }

    static func isPlainText(_ ext: String) -> Bool {
        plainTextExtensions.contains(ext)
    }

    static func isImage(_ ext: String) -> Bool {
        imageExtensions.contains(ext)
    }

    static func isSpreadsheet(_ ext: String) -> Bool {
        spreadsheetExtensions.contains(ext)
    }

    static func isDocument(_ ext: String) -> Bool {
        pdfExtensions.contains(ext)
            || textutilExtensions.contains(ext)
            || plainTextExtensions.contains(ext)
            || spreadsheetExtensions.contains(ext)
    }

    static func isSupported(_ ext: String) -> Bool {
        isImage(ext) || isDocument(ext)
    }

    /// UTTypes for the file picker dialog.
    static var allowedContentTypes: [UTType] {
        [.image, .pdf, .rtf, .rtfd, .plainText, .commaSeparatedText,
         .json, .xml, .yaml, .html, .sourceCode, .spreadsheet, .item]
    }
}
