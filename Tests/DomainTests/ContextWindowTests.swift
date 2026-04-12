import Foundation
import Testing
@testable import AirplaneAI

@Suite("ContextWindow")
struct ContextWindowTests {
    private func manifest(appDefault: Int, capability: Int) -> ModelManifest {
        ModelManifest(
            sourceModelId: "x", sourceChannel: "x", sourceRevision: "x",
            conversionRuntimeRevision: "x", quantization: "Q4_K_M",
            ggufSha256: "", modelCapabilityContext: capability,
            appDefaultContext: appDefault, license: ""
        )
    }

    private func profile(defaultCtx: Int) -> RuntimeProfile {
        RuntimeProfile(memoryClass: .supported16to23, defaultContext: defaultCtx,
                       maxSupportedContext: defaultCtx, gpuLayerPolicy: .none,
                       batchSize: 512, ubatchSize: 512, flashAttention: .off, warmupEnabled: false)
    }

    @Test func effectiveIsMinOfManifestAndProfile() {
        let w = ContextWindow.resolve(manifest: manifest(appDefault: 8192, capability: 32768),
                                      profile: profile(defaultCtx: 16384))
        #expect(w.effective == 8192)
        #expect(w.modelCapability == 32768)
        #expect(w.appDefault == 8192)
    }

    @Test func profileCapCanClampManifestDefault() {
        let w = ContextWindow.resolve(manifest: manifest(appDefault: 16384, capability: 32768),
                                      profile: profile(defaultCtx: 4096))
        #expect(w.effective == 4096)
    }

    @Test func cutoffNilWhenAllMessagesFit() {
        let w = ContextWindow(modelCapability: 32768, appDefault: 8192, effective: 1000)
        let msgs = [
            ChatMessage(role: .user, content: String(repeating: "x", count: 100)),
            ChatMessage(role: .assistant, content: String(repeating: "y", count: 100)),
        ]
        let cut = w.cutoffIndex(messages: msgs) { $0.content.count }
        #expect(cut == nil)
    }

    @Test func cutoffReturnsIndexWhenOldestOverflow() {
        let w = ContextWindow(modelCapability: 32768, appDefault: 8192, effective: 100)
        let msgs = (0..<10).map { i in
            ChatMessage(role: .user, content: String(repeating: "a", count: 30))
        }
        let cut = w.cutoffIndex(messages: msgs) { $0.content.count }
        // Each msg = 30 tokens; budget 100. Walk newest→oldest: 30,60,90,120>budget.
        // Cutoff index = 10 - 3 = 7. So indices 0..<7 are out of context.
        #expect(cut == 7)
    }
}
