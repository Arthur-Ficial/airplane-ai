import Foundation

@MainActor
public final class AppWiring {
    public let state: AppState
    public let modelController: ModelController
    public let chatController: ChatController
    public let conversationController: ConversationController
    public let lifecycle: LifecycleManager
    public let store: any ConversationStore
    public let liveSpeechInput: LiveSpeechInput
    public let speechOutput: SpeechOutput

    public init() throws {
        let state = AppState()
        let engine = LlamaSwiftEngine()

        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("AirplaneAI", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let storeURL = base.appendingPathComponent("store.sqlite")
        let backupDir = base.appendingPathComponent("Backups")
        let store = try SwiftDataConversationStore(storeURL: storeURL, backupDirectory: backupDir)

        let manifest: ModelManifest
        let modelURL: URL
        if let url = ModelLocator.bundledModelURL() {
            modelURL = url
        } else {
            throw AppError.modelMissing
        }
        manifest = (try? ModelLocator.bundledManifest()) ?? ModelManifest(
            sourceModelId: "unknown", sourceChannel: "unknown", sourceRevision: "unknown",
            conversionRuntimeRevision: "unknown", quantization: "unknown",
            ggufSha256: "", modelCapabilityContext: 8192, appDefaultContext: 8192, license: "unknown"
        )

        let profile = RuntimeProfileProvider().current()
        let userOverride = UserDefaults.standard.integer(forKey: "airplane.contextOverride")
        let contextWindow = ContextWindow.resolve(
            manifest: manifest, profile: profile,
            override: userOverride > 0 ? userOverride : nil
        )
        let contextManager = ContextManager(maxContextTokens: contextWindow.effective)
        let sysPrompt = ModelLocator.bundledSystemPrompt()
        state.contextWindow = contextWindow

        self.state = state
        self.modelController = ModelController(
            state: state, engine: engine,
            resourceGuard: ResourceGuard(),
            integrity: ModelIntegrity(),
            modelURL: modelURL, manifest: manifest
        )
        self.chatController = ChatController(
            state: state, engine: engine, store: store,
            contextManager: contextManager, tokenCounter: engine,
            systemPrompt: sysPrompt
        )
        self.conversationController = ConversationController(state: state, store: store)
        self.lifecycle = LifecycleManager()
        self.store = store
        self.liveSpeechInput = LiveSpeechInput()
        self.speechOutput = SpeechOutput()
    }

    public func boot() async {
        lifecycle.install(handlers: .init(
            onWillTerminate: { [engine = chatController] in Task { @MainActor in engine.stop() } },
            onWillSleep: { [engine = chatController] in Task { @MainActor in engine.stop() } },
            onDidWake: {}
        ))

        // Boot progress: conversation load → model verify → load → warmup.
        state.boot = BootProgress(step: "Loading conversations", detail: "database", fraction: 0.02)
        await conversationController.loadAll()
        await modelController.bringUp()

        if state.modelState == .ready {
            Task { await chatController.backfillTitles() }
        }
    }
}
