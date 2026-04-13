import Foundation

/// Defines which file extensions DocumentExtractor can handle.
enum SupportedFormats {
    // PDF handled via PDFKit
    private static let pdfExtensions: Set<String> = ["pdf"]

    // Word/RTF handled via /usr/bin/textutil
    private static let textutilExtensions: Set<String> = [
        "docx", "doc", "rtf", "rtfd",
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

    static func isSupported(_ ext: String) -> Bool {
        pdfExtensions.contains(ext)
            || textutilExtensions.contains(ext)
            || plainTextExtensions.contains(ext)
    }
}
