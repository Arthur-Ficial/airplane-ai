import Foundation

public enum ModelLocator {
    // Returns the bundled GGUF URL. Spec SSOT: only place we reach for it.
    public static func bundledModelURL() -> URL? {
        if let u = Bundle.module.url(forResource: "airplane-model", withExtension: "gguf", subdirectory: "models") {
            return u
        }
        // Sibling resource bundle (applies to tests + swift run).
        let exec = Bundle.main.bundleURL.deletingLastPathComponent()
        let candidates = [
            exec.appendingPathComponent("AirplaneAI_AirplaneAI.bundle/models/airplane-model.gguf"),
            exec.appendingPathComponent("AirplaneAI_AirplaneAI.bundle/airplane-model.gguf"),
        ]
        for c in candidates where FileManager.default.fileExists(atPath: c.path) { return c }
        return nil
    }

    public static func bundledManifest() throws -> ModelManifest {
        guard let url = Bundle.module.url(forResource: "airplane-model-manifest", withExtension: "json", subdirectory: "models") else {
            throw AppError.modelMissing
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ModelManifest.self, from: data)
    }

    public static func bundledSystemPrompt() -> String {
        guard let url = Bundle.module.url(forResource: "SystemPrompt", withExtension: "txt", subdirectory: "prompts"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
