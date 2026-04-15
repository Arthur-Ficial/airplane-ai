import Foundation

/// Boots a minimal engine + store pair without any AppKit/SwiftUI, runs the
/// requested CLI command, and returns an exit code. Used when the binary is
/// invoked with CLI flags rather than launched as a GUI.
@MainActor
enum HeadlessCLIBoot {
    static func run(arguments: [String]) async -> Int32 {
        let output = StandardCLIOutput()

        // Fast path for help/version: do not load the model.
        if let early = try? CLIArguments.parse(arguments), early.mode == .help || early.mode == .version {
            let runner = CLIRunner(
                engine: DummyEngine(),
                store: DummyStore(),
                systemPrompt: ""
            )
            return await runner.run(arguments: arguments, output: output)
        }

        // Locate bundled model + manifest. Same pipeline as AppWiring.
        guard let modelURL = ModelLocator.bundledModelURL() else {
            output.writeError("error: bundled model missing; app cannot answer\n")
            return 1
        }
        let manifest = (try? ModelLocator.bundledManifest()) ?? ModelManifest(
            sourceModelId: "unknown", sourceChannel: "unknown", sourceRevision: "unknown",
            conversionRuntimeRevision: "unknown", quantization: "unknown",
            ggufSha256: "", modelCapabilityContext: 8192, appDefaultContext: 8192, license: "unknown"
        )

        let profile = RuntimeProfileProvider().current()
        let window = ContextWindow.resolve(manifest: manifest, profile: profile, override: nil)
        let engine = LlamaSwiftEngine()

        do {
            try await engine.loadModel(at: modelURL, contextWindow: window.effective)
        } catch {
            output.writeError("error: model load failed: \(error.localizedDescription)\n")
            return 1
        }

        // Use the same SwiftData store as the GUI so CLI-created chats appear there.
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("AirplaneAI", isDirectory: true)
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        } catch {
            output.writeError("error: could not create store directory: \(error.localizedDescription)\n")
            return 1
        }

        let storeURL = base.appendingPathComponent("store.sqlite")
        let backupDir = base.appendingPathComponent("Backups")
        let store: ConversationStore
        do {
            store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)
        } catch {
            output.writeError("error: could not open store: \(error.localizedDescription)\n")
            return 1
        }

        let system = ModelLocator.bundledSystemPrompt()
        let runner = CLIRunner(engine: engine, store: store, systemPrompt: system)
        return await runner.run(arguments: arguments, output: output)
    }
}

private struct DummyEngine: InferenceEngine {
    var isModelLoaded: Bool { get async { false } }
    var loadedModelInfo: ModelInfo? { get async { nil } }
    func loadModel(at path: URL, contextWindow: Int) async throws {}
    func warmup() async {}
    func unloadModel() async {}
    func cancelGeneration() async {}
    func countTokens(in text: String) async throws -> Int { 0 }
    func generate(messages: [ChatMessage], parameters: GenerationParameters) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}

private struct DummyStore: ConversationStore {
    func allConversations() async throws -> [Conversation] { [] }
    func conversation(id: UUID) async throws -> Conversation? { nil }
    func save(_ conversation: Conversation) async throws {}
    func delete(id: UUID) async throws {}
    func saveBackupSnapshot(_ conversations: [Conversation]) async throws {}
    func loadLatestBackupSnapshot() async throws -> [Conversation]? { nil }
}
