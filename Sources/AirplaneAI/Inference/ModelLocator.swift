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
        let today = Self.dateFormatter.string(from: Date())
        return text.replacingOccurrences(of: "{DATE}", with: today)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

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
        // swift test: resource bundle is next to the xctest bundle in .build/<arch>/<config>/.
        bases.append(Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("AirplaneAI_AirplaneAI.bundle"))
        // Dev fallback: walk up from cwd (SwiftPM sets it to project root during build/test).
        // Also try from the binary if it lives inside the project tree.
        let candidates = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
                .resolvingSymlinksInPath().deletingLastPathComponent(),
        ]
        for start in candidates {
            var dir = start
            for _ in 0..<10 {
                if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                    let devRes = dir.appendingPathComponent("Sources/AirplaneAI/Resources")
                    bases.append(devRes)
                    bases.append(devRes.appendingPathComponent("models"))
                    bases.append(devRes.appendingPathComponent("prompts"))
                    // Also check the SwiftPM build output resource bundle.
                    let buildRes = dir.appendingPathComponent(".build")
                    for arch in ["arm64-apple-macosx", "x86_64-apple-macosx"] {
                        for config in ["debug", "release"] {
                            bases.append(buildRes.appendingPathComponent(arch)
                                .appendingPathComponent(config)
                                .appendingPathComponent("AirplaneAI_AirplaneAI.bundle"))
                        }
                    }
                    break
                }
                let parent = dir.deletingLastPathComponent()
                if parent.path == dir.path { break }
                dir = parent
            }
        }
        return bases
    }
}
