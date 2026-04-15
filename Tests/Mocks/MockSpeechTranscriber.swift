import Foundation
@testable import AirplaneAI

public final class MockSpeechTranscriber: SpeechTranscribing, @unchecked Sendable {
    public var available = true
    public var transcript = "Hello world"
    public var shouldThrow = false

    public var isAvailable: Bool { get async { available } }

    public func transcribe(_ audioURL: URL) async throws -> String {
        if shouldThrow {
            throw AppError.generationFailed(summary: "mock speech error")
        }
        return transcript
    }
}
