import Foundation
import Testing
@testable import AirplaneAI

@Suite("Context window config (#66)")
struct ContextWindowConfigTests {
    @Test func bundledManifestHasFullCapability() throws {
        let m = try ModelLocator.bundledManifest()
        #expect(m.modelCapabilityContext == 32768)
        // App default = full capability; actual runtime gets clamped by profile.
        #expect(m.appDefaultContext == 32768)
    }

    // Realistic per-RAM defaults — KV cache at F16 ≈ 140 KB/token for Gemma-3n-E4B.
    // Leave headroom for model (5GB) + macOS (~4GB).
    @Test func realisticRamBasedDefaults() {
        let p = RuntimeProfileProvider()
        #expect(p.profile(for: .supported16to23).defaultContext == 8192,
                "16 GB Mac: 8K ctx (1.1 GB KV) alongside 5 GB model is safe")
        #expect(p.profile(for: .supported24to31).defaultContext == 16384,
                "24 GB Mac: 16K ctx (2.3 GB KV)")
        #expect(p.profile(for: .supported32to63).defaultContext == 32768,
                "32 GB Mac: full 32K (4.6 GB KV)")
        #expect(p.profile(for: .supported64plus).defaultContext == 32768,
                "64+ GB Mac: model ceiling is 32K")
    }

    @Test func userOverrideReplacesProfileDefault() {
        let profile = RuntimeProfile(
            memoryClass: .supported16to23, defaultContext: 8192, maxSupportedContext: 8192,
            gpuLayerPolicy: .fixed(24), batchSize: 512, ubatchSize: 512,
            flashAttention: .auto, warmupEnabled: true
        )
        let m = ModelManifest(
            sourceModelId: "g", sourceChannel: "x", sourceRevision: "x",
            conversionRuntimeRevision: "x", quantization: "Q4_K_M",
            ggufSha256: "", modelCapabilityContext: 32768,
            appDefaultContext: 32768, license: ""
        )
        // User explicitly sets 16K (override > profile default but <= capability).
        let w = ContextWindow.resolve(manifest: m, profile: profile, override: 16384)
        #expect(w.effective == 16384)
    }

    @Test func overrideClampedToCapability() {
        let profile = RuntimeProfile(
            memoryClass: .supported64plus, defaultContext: 32768, maxSupportedContext: 32768,
            gpuLayerPolicy: .all, batchSize: 1024, ubatchSize: 1024,
            flashAttention: .on, warmupEnabled: true
        )
        let m = ModelManifest(
            sourceModelId: "g", sourceChannel: "x", sourceRevision: "x",
            conversionRuntimeRevision: "x", quantization: "Q4_K_M",
            ggufSha256: "", modelCapabilityContext: 32768,
            appDefaultContext: 32768, license: ""
        )
        // User requests 128K — model can't; clamp to capability.
        let w = ContextWindow.resolve(manifest: m, profile: profile, override: 128000)
        #expect(w.effective == 32768)
    }

    @Test func nilOverrideFallsBackToProfile() {
        let profile = RuntimeProfile(
            memoryClass: .supported16to23, defaultContext: 8192, maxSupportedContext: 8192,
            gpuLayerPolicy: .fixed(24), batchSize: 512, ubatchSize: 512,
            flashAttention: .auto, warmupEnabled: true
        )
        let m = ModelManifest(
            sourceModelId: "g", sourceChannel: "x", sourceRevision: "x",
            conversionRuntimeRevision: "x", quantization: "Q4_K_M",
            ggufSha256: "", modelCapabilityContext: 32768,
            appDefaultContext: 32768, license: ""
        )
        let w = ContextWindow.resolve(manifest: m, profile: profile, override: nil)
        #expect(w.effective == 8192, "Auto mode respects profile default")
    }
}
