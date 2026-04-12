import Foundation

public struct ModelInfo: Codable, Sendable, Equatable {
    public let name: String
    public let sizeBytes: Int64
    public let sha256: String
    public let contextWindow: Int

    public init(name: String, sizeBytes: Int64, sha256: String, contextWindow: Int) {
        self.name = name
        self.sizeBytes = sizeBytes
        self.sha256 = sha256
        self.contextWindow = contextWindow
    }
}

public struct ModelManifest: Codable, Sendable, Equatable {
    public let sourceModelId: String
    public let sourceChannel: String
    public let sourceRevision: String
    public let conversionRuntimeRevision: String
    public let quantization: String
    public let ggufSha256: String
    public let modelCapabilityContext: Int
    public let appDefaultContext: Int
    public let license: String

    enum CodingKeys: String, CodingKey {
        case sourceModelId = "source_model_id"
        case sourceChannel = "source_channel"
        case sourceRevision = "source_revision"
        case conversionRuntimeRevision = "conversion_runtime_revision"
        case quantization
        case ggufSha256 = "gguf_sha256"
        case modelCapabilityContext = "model_capability_context"
        case appDefaultContext = "app_default_context"
        case license
    }
}
