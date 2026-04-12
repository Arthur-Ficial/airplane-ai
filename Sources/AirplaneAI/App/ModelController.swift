import Foundation

@MainActor
public final class ModelController {
    private let state: AppState
    private let engine: any InferenceEngine
    private let resourceGuard: ResourceGuard
    private let integrity: ModelIntegrity
    private let modelURL: URL
    private let manifest: ModelManifest

    public init(
        state: AppState,
        engine: any InferenceEngine,
        resourceGuard: ResourceGuard,
        integrity: ModelIntegrity,
        modelURL: URL,
        manifest: ModelManifest
    ) {
        self.state = state
        self.engine = engine
        self.resourceGuard = resourceGuard
        self.integrity = integrity
        self.modelURL = modelURL
        self.manifest = manifest
    }

    public func bringUp() async {
        do {
            state.modelState = .verifyingModel
            try resourceGuard.checkBeforeModelLoad()
            try integrity.verify(file: modelURL, expected: manifest.ggufSha256)
            state.modelState = .loadingModel
            try await engine.loadModel(at: modelURL, contextWindow: manifest.appDefaultContext)
            state.modelState = .warmingModel
            // Warmup is engine-internal if applicable; for the mock it's a no-op.
            state.modelState = .ready
        } catch AppError.modelVerificationFailed {
            state.modelState = .modelCorrupt
        } catch let e as AppError {
            state.modelState = .blockedInsufficientResources(e)
        } catch {
            state.modelState = .loadFailed(error.localizedDescription)
        }
    }

    public func shutDown() async {
        state.modelState = .unloading
        await engine.unloadModel()
        state.modelState = .cold
    }
}
