import Foundation

public enum ModelLocator {
    // Never call Bundle.module — SwiftPM's generated accessor crashes when run
    // from inside a .app. Use Bundle.main + explicit search paths instead.
    public static func bundledModelURL() -> URL? { find("airplane-model.gguf") }
    public static func bundledManifestURL() -> URL? { find("airplane-model-manifest.json") }
    public static func bundledSystemPromptURL() -> URL? { find("SystemPrompt.txt") }

    public static func bundledManifest() throws -> ModelManifest {
        guard let url = bundledManifestURL() else { throw AppError.modelMissing }
        return try JSONDecoder().decode(ModelManifest.self, from: Data(contentsOf: url))
    }

    public static func bundledSystemPrompt() -> String {
        guard let url = bundledSystemPromptURL(),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Search order covers .app, swift run, swift test, and dev-tree execution.
    private static func find(_ name: String) -> URL? {
        for base in searchBases() {
            let url = base.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private static func searchBases() -> [URL] {
        var bases: [URL] = []
        let appResources = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        bases.append(appResources)
        bases.append(Bundle.main.bundleURL)
        bases.append(Bundle.main.bundleURL.deletingLastPathComponent())
        bases.append(appResources.appendingPathComponent("AirplaneAI_AirplaneAI.bundle"))
        bases.append(Bundle.main.bundleURL.appendingPathComponent("AirplaneAI_AirplaneAI.bundle"))
        // Dev fallback so tests and `swift run` work without the .app.
        bases.append(URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/Sources/AirplaneAI/Resources"))
        bases.append(URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/Sources/AirplaneAI/Resources/models"))
        bases.append(URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/Sources/AirplaneAI/Resources/prompts"))
        return bases
    }
}
