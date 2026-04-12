import Foundation

// Versioned profile table. Spec §3: tuning is data, not formula.
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
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 8192, maxSupportedContext: 8192,
                gpuLayerPolicy: .fixed(24), batchSize: 512, ubatchSize: 512,
                flashAttention: .auto, warmupEnabled: true
            )
        case .supported24to31:
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 16384, maxSupportedContext: 16384,
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
            return RuntimeProfile(
                memoryClass: mc, defaultContext: 65536, maxSupportedContext: 65536,
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
