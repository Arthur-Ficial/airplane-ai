import Foundation

public protocol SpeechTranscribing: Sendable {
    /// Whether speech recognition is currently available.
    var isAvailable: Bool { get async }
    /// Transcribe audio from a file URL. Fails hard if on-device is unavailable.
    func transcribe(_ audioURL: URL) async throws -> String
}
