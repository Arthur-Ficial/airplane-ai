import Foundation

@MainActor
public final class AppWiring {
    public let state: AppState
    public let modelController: ModelController
    public let chatController: ChatController
    public let conversationController: ConversationController
    public let lifecycle: LifecycleManager
    public let store: any ConversationStore

    public init() throws {
        let state = AppState()
        let engine = LlamaSwiftEngine()

        // Persistence lives under Application Support inside the sandbox.
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
        let contextManager = ContextManager(maxContextTokens: min(profile.defaultContext, manifest.appDefaultContext))
        let sysPrompt = ModelLocator.bundledSystemPrompt()

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
    }

    public func boot() async {
        lifecycle.install(handlers: .init(
            onWillTerminate: { [engine = chatController] in Task { @MainActor in engine.stop() } },
            onWillSleep: { [engine = chatController] in Task { @MainActor in engine.stop() } },
            onDidWake: {}
        ))
        await conversationController.loadAll()
        await modelController.bringUp()
        // After the model is ready, backfill AI titles for any default-named chats.
        if state.modelState == .ready {
            Task { await chatController.backfillTitles() }
        }
    }
}
