import Foundation

// Versioned profile table. Spec §3: tuning is data, not formula.
// Values chosen to max out Gemma-3n-E4B's 32K native context where memory allows.
// KV cache size at 32K ≈ 2-4 GB (Q4_K_M); fits comfortably alongside the 5 GB model
// on 16 GB unified memory with headroom. Context never exceeds the model's
// trained ceiling (32768) — higher would require RoPE scaling and hurts quality.
public struct RuntimeProfileProvider: Sendable {
    public init() {}

    public func profile(for mc: MemoryClass) -> RuntimeProfile {
        switch mc {
        case .unsupported8to15:
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 4096, maxSupportedContext: 4096,
                gpuLayerPolicy: .none, batchSize: 256, ubatchSize: 256,
                flashAttention: .off, warmupEnabled: false
            )
        case .supported16to23:
            // 16 GB: conservative but still generous. ~1.5 GB KV at 16K.
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 16384, maxSupportedContext: 16384,
                gpuLayerPolicy: .fixed(24), batchSize: 512, ubatchSize: 512,
                flashAttention: .auto, warmupEnabled: true
            )
        case .supported24to31:
            // 24-31 GB: full native 32K capability. ~3 GB KV.
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 32768, maxSupportedContext: 32768,
                gpuLayerPolicy: .fixed(36), batchSize: 512, ubatchSize: 512,
                flashAttention: .on, warmupEnabled: true
            )
        case .supported32to63:
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 32768, maxSupportedContext: 32768,
                gpuLayerPolicy: .all, batchSize: 1024, ubatchSize: 512,
                flashAttention: .on, warmupEnabled: true
            )
        case .supported64plus:
            // Model ceiling — not going higher without RoPE extension.
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 32768, maxSupportedContext: 32768,
                gpuLayerPolicy: .all, batchSize: 1024, ubatchSize: 1024,
                flashAttention: .on, warmupEnabled: true
            )
        }
    }

    public func current() -> RuntimeProfile {
        profile(for: .from(unifiedMemoryGB: Self.currentUnifiedMemoryGB()))
    }

    static func currentUnifiedMemoryGB() -> Int {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return Int((Double(bytes) / 1_073_741_824.0).rounded())
    }
}
