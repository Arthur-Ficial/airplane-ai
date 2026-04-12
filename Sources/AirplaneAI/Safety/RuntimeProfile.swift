import Foundation

public enum MemoryClass: Sendable, Equatable, CaseIterable {
    case unsupported8to15
    case supported16to23
    case supported24to31
    case supported32to63
    case supported64plus

    public static func from(unifiedMemoryGB gb: Int) -> MemoryClass {
        switch gb {
        case ..<16: .unsupported8to15
        case 16..<24: .supported16to23
        case 24..<32: .supported24to31
        case 32..<64: .supported32to63
        default: .supported64plus
        }
    }

    public var isSupported: Bool { self != .unsupported8to15 }
}

public enum GPULayerPolicy: Sendable, Equatable {
    case none
    case fixed(Int)
    case all
}

public enum FlashAttentionPolicy: Sendable, Equatable {
    case off, on, auto
}

public struct RuntimeProfile: Sendable, Equatable {
    public let memoryClass: MemoryClass
    public let defaultContext: Int
    public let maxSupportedContext: Int
    public let gpuLayerPolicy: GPULayerPolicy
    public let batchSize: Int
    public let ubatchSize: Int
    public let flashAttention: FlashAttentionPolicy
    public let warmupEnabled: Bool
}
