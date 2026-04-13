import Foundation

public protocol SpeechTranscribing: Sendable {
    /// Whether on-device speech recognition is available.
    var isAvailable: Bool { get }
    /// Transcribe audio from a file URL. Fails hard if on-device is unavailable.
    func transcribe(_ audioURL: URL) async throws -> String
}
