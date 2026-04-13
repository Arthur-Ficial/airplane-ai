import Foundation

public enum Attachment: Codable, Sendable, Equatable {
    case image(data: Data, extractedText: String)
    case document(text: String, filename: String, fileType: String)
    case audio(transcript: String)

    /// The plain text the model will see for this attachment.
    public var extractedText: String {
        switch self {
        case .image(_, let t): return t
        case .document(let t, _, _): return t
        case .audio(let t): return t
        }
    }
}
