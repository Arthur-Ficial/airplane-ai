import Foundation
import Speech

/// Speech-to-text via SFSpeechRecognizer. Prefers on-device mode when Apple provides it.
public actor SpeechTranscriber: SpeechTranscribing {
    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    public var isAvailable: Bool {
        SFSpeechRecognizer(locale: locale)?.isAvailable ?? false
    }

    public func transcribe(_ audioURL: URL) async throws -> String {
        try await Self.runRecognitionTask(locale: locale, audioURL: audioURL)
    }

    // SFSpeechRecognizer.recognitionTask delivers its callback on a background queue.
    // Constructing the recognizer AND starting the task from a nonisolated helper keeps
    // the non-Sendable SFSpeechRecognizer from crossing isolation boundaries, and
    // prevents the callback closure from inheriting actor isolation — which would
    // trip swift_task_checkIsolatedSwift when the system invokes it off-actor and
    // trap with EXC_BREAKPOINT under Swift 6.
    private nonisolated static func runRecognitionTask(
        locale: Locale,
        audioURL: URL
    ) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw AppError.generationFailed(summary: "Speech recognizer unavailable")
        }
        recognizer.defaultTaskHint = .dictation
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
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
