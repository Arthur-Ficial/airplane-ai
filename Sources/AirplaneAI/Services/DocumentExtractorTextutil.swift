import Foundation

/// Runs `/usr/bin/textutil -convert txt -stdout` to extract text from Word/RTF files.
extension DocumentExtractor {
    func runTextutil(on url: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = ["-convert", "txt", "-stdout", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            throw AppError.generationFailed(
                summary: "textutil failed for \(url.lastPathComponent)"
            )
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
