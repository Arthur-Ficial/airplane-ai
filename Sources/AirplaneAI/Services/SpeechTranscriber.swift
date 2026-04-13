import Foundation
import Speech

/// On-device speech-to-text via SFSpeechRecognizer. Fails hard if on-device is unavailable.
public final class SpeechTranscriber: SpeechTranscribing, @unchecked Sendable {
    private let recognizer: SFSpeechRecognizer?

    public init(locale: Locale = .current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        recognizer?.defaultTaskHint = .dictation
    }

    public var isAvailable: Bool {
        guard let r = recognizer else { return false }
        return r.isAvailable && r.supportsOnDeviceRecognition
    }

    public func transcribe(_ audioURL: URL) async throws -> String {
        guard let recognizer else {
            throw AppError.generationFailed(summary: "Speech recognizer unavailable")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw AppError.generationFailed(summary: "On-device speech not supported")
        }
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    cont.resume(throwing: AppError.generationFailed(summary: error.localizedDescription))
                } else if let result, result.isFinal {
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
