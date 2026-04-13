import Foundation

public enum Attachment: Codable, Sendable, Equatable {
    case image(data: Data, extractedText: String)
    case document(text: String, filename: String, fileType: String)
    case audio(transcript: String)

    /// Rough token estimate: ~4 chars per token for English text.
    public var estimatedTokenCount: Int {
        let text: String
        switch self {
        case .image(_, let t): text = t
        case .document(let t, _, _): text = t
        case .audio(let t): text = t
        }
        return max(1, text.count / 4)
    }

    /// The plain text the model will see for this attachment.
    public var extractedText: String {
        switch self {
        case .image(_, let t): return t
        case .document(let t, _, _): return t
        case .audio(let t): return t
        }
    }
}
