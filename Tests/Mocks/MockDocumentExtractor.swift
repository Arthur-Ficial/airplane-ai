import Foundation
@testable import AirplaneAI

public final class MockDocumentExtractor: DocumentExtracting, @unchecked Sendable {
    public var result = DocumentExtraction(
        text: "mock text", filename: "test.txt", fileType: "txt"
    )
    public var shouldThrow = false

    public func extract(from url: URL) async throws -> DocumentExtraction {
        if shouldThrow {
            throw AppError.generationFailed(summary: "mock")
        }
        return result
    }
}
