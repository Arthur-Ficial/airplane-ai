import Foundation

public protocol DocumentExtracting: Sendable {
    func extract(from url: URL) async throws -> DocumentExtraction
}

public struct DocumentExtraction: Sendable, Equatable {
    public let text: String
    public let filename: String
    public let fileType: String

    public init(text: String, filename: String, fileType: String) {
        self.text = text
        self.filename = filename
        self.fileType = fileType
    }
}
