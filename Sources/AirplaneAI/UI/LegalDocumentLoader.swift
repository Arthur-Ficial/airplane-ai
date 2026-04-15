import Foundation

enum LegalDocumentLoader {
    static func load(resourceName: String, fallbackTitle: String) -> String {
        let candidates: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(resourceName).txt"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AirplaneAI_AirplaneAI.bundle/\(resourceName).txt"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("AirplaneAI_AirplaneAI.bundle/\(resourceName).txt"),
        ]
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }

        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<10 {
            let devPath = dir.appendingPathComponent("Sources/AirplaneAI/Resources/licenses/\(resourceName).txt")
            if let text = try? String(contentsOf: devPath, encoding: .utf8) {
                return text
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return "Unable to load \(fallbackTitle). Please reinstall Airplane AI."
    }
}
