import Foundation
import Testing
@testable import AirplaneAI

// Tests that assert the CHOSEN values after #65 — bigger context by default.
@Suite("Context window config (#65)")
struct ContextWindowConfigTests {
    @Test func bundledManifestUsesFullModelCapability() throws {
        let m = try ModelLocator.bundledManifest()
        #expect(m.modelCapabilityContext == 32768, "Gemma-3n-E4B-it native context is 32K")
        #expect(m.appDefaultContext == 32768, "App must ship the full capability, not a conservative subset")
    }

    @Test func runtimeProfilesBumpedToMatchCapability() {
        let p = RuntimeProfileProvider()
        // 16-23 GB: bumped from 8K → 16K (still safe; ~3GB KV + 5GB model fits in 16GB).
        #expect(p.profile(for: .supported16to23).defaultContext == 16384)
        // 24-31 GB: bumped to full 32K.
        #expect(p.profile(for: .supported24to31).defaultContext == 32768)
        // 32+ GB: full 32K (the model's trained ceiling).
        #expect(p.profile(for: .supported32to63).defaultContext == 32768)
        #expect(p.profile(for: .supported64plus).defaultContext == 32768)
    }

    @Test func effectiveIsCappedAtModelCapability() {
        // Even if a profile quotes higher, the model can't handle more than 32K without RoPE.
        let profile = RuntimeProfile(
            memoryClass: .supported64plus, defaultContext: 128000,
            maxSupportedContext: 128000, gpuLayerPolicy: .all,
            batchSize: 1024, ubatchSize: 1024, flashAttention: .on, warmupEnabled: true
        )
        let m = ModelManifest(
            sourceModelId: "g", sourceChannel: "x", sourceRevision: "x",
            conversionRuntimeRevision: "x", quantization: "Q4_K_M",
            ggufSha256: "", modelCapabilityContext: 32768,
            appDefaultContext: 32768, license: ""
        )
        let w = ContextWindow.resolve(manifest: m, profile: profile)
        #expect(w.effective == 32768)
    }
}
