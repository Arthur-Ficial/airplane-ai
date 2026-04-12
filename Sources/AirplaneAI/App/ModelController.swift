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
            report(step: "Checking system resources", detail: "memory, disk, unified pool", fraction: 0.05)
            try resourceGuard.checkBeforeModelLoad()

            state.modelState = .verifyingModel
            report(step: "Verifying model integrity", detail: "SHA-256 over \(manifest.quantization) \(manifest.sourceModelId)", fraction: 0.15)
            try integrity.verify(file: modelURL, expected: manifest.ggufSha256)
            report(step: "Verified", detail: String(manifest.ggufSha256.prefix(12)) + "…", fraction: 0.35)

            state.modelState = .loadingModel
            report(step: "Loading model", detail: "memory-mapping GGUF (Metal offload)", fraction: 0.55)
            try await engine.loadModel(at: modelURL, contextWindow: manifest.appDefaultContext)
            state.modelInfo = await engine.loadedModelInfo

            state.modelState = .warmingModel
            report(step: "Warming up", detail: "initializing KV cache", fraction: 0.85)

            state.modelState = .ready
            report(step: "Ready", detail: "\(manifest.sourceModelId) · ctx \(manifest.appDefaultContext)", fraction: 1.0)
        } catch AppError.modelVerificationFailed {
            state.modelState = .modelCorrupt
            report(step: "Model corrupt", detail: "SHA-256 mismatch", fraction: 1.0)
        } catch let e as AppError {
            state.modelState = .blockedInsufficientResources(e)
            report(step: "Blocked", detail: e.errorDescription ?? "resource check failed", fraction: 1.0)
        } catch {
            state.modelState = .loadFailed(error.localizedDescription)
            report(step: "Load failed", detail: error.localizedDescription, fraction: 1.0)
        }
    }

    private func report(step: String, detail: String, fraction: Double) {
        state.boot = BootProgress(step: step, detail: detail, fraction: fraction)
    }

    public func shutDown() async {
        state.modelState = .unloading
        await engine.unloadModel()
        state.modelState = .cold
    }
}
