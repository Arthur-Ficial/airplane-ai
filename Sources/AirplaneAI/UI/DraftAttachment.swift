import Foundation
import AppKit

/// Pending attachment in the composer, not yet sent with a message.
@MainActor
@Observable
public final class DraftAttachment: Identifiable {
    public let id = UUID()
    public let filename: String
    public let fileType: String
    public var thumbnail: NSImage?
    public var state: ParseState = .parsing
    public var attachment: Attachment?
    public var tokenCount: Int?

    public enum ParseState {
        case parsing, ready, error(String)
    }

    public init(filename: String, fileType: String, thumbnail: NSImage? = nil) {
        self.filename = filename
        self.fileType = fileType
        self.thumbnail = thumbnail
    }
}
