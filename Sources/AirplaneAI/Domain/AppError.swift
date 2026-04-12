import Foundation

public enum AppError: LocalizedError, Sendable, Equatable, Hashable {
    case insufficientMemory(requiredGB: Double, availableGB: Double)
    case insufficientDisk(requiredGB: Double, availableGB: Double)
    case modelMissing
    case modelCorrupt
    case modelVerificationFailed
    case inputTooLarge(maxTokens: Int)
    case modelLoadFailed(summary: String)
    case generationFailed(summary: String)
    case persistenceFailed(summary: String)
    case migrationFailed

    public var errorDescription: String? {
        switch self {
        case .insufficientMemory(let r, let a):
            return "Not enough memory. Required \(r.formatted()) GB, available \(a.formatted()) GB."
        case .insufficientDisk(let r, let a):
            return "Not enough disk space. Required \(r.formatted()) GB, available \(a.formatted()) GB."
        case .modelMissing: return "AI model is missing."
        case .modelCorrupt: return "AI model is damaged."
        case .modelVerificationFailed: return "Model verification failed."
        case .inputTooLarge(let m): return "Message is too long. Max \(m) tokens."
        case .modelLoadFailed(let s): return "Model load failed: \(s)"
        case .generationFailed(let s): return "Generation failed: \(s)"
        case .persistenceFailed(let s): return "Persistence failed: \(s)"
        case .migrationFailed: return "Data migration failed."
        }
    }
}
