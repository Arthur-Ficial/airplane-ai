import AppKit
@testable import AirplaneAI

public final class MockImageAnalyzer: ImageAnalyzing, @unchecked Sendable {
    public var result: String = "CONTEXT: image\nOCR:\n  mock text\nLABELS: test\nDOC: no"
    public var shouldThrow = false

    public func analyze(_ image: NSImage) async throws -> String {
        if shouldThrow { throw AppError.generationFailed(summary: "mock") }
        return result
    }
}
