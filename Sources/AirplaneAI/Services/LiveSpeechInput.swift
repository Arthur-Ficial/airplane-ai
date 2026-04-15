import Foundation
import Speech
import AVFoundation

/// Live microphone speech-to-text via SFSpeechRecognizer. On-device only.
@MainActor
@Observable
public final class LiveSpeechInput: LiveSpeechInputting {
    public var isListening = false
    public var transcript = ""
    public var errorMessage: String?

    private let preferences: AudioPreferences
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var userStoppedSession = false

    public init(preferences: AudioPreferences) {
        self.preferences = preferences
        self.recognizer = nil
    }

    public func requestPermissions() async -> Bool {
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                errorMessage = L.micMicrophonePermissionDenied
                return false
            }
        } else if audioStatus != .authorized {
            errorMessage = L.micMicrophonePermissionDenied
            return false
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let granted = await Self.requestSpeechAuthorization()
            if !granted {
                errorMessage = L.micSpeechPermissionDenied
                return false
            }
        } else if speechStatus != .authorized {
            errorMessage = L.micSpeechPermissionDenied
            return false
        }

        errorMessage = nil
        return true
    }

    // TCC delivers SFSpeechRecognizer.requestAuthorization's callback on an arbitrary
    // dispatch queue. Keep this nonisolated so the closure doesn't inherit @MainActor
    // and trip swift_task_checkIsolatedSwift at runtime.
    private nonisolated static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    // AVAudioNode delivers tap callbacks on RealtimeMessenger.mServiceQueue. Install
    // from a nonisolated helper so the closure doesn't inherit @MainActor and trip
    // swift_task_checkIsolatedSwift on every audio buffer.
    // SFSpeechAudioBufferRecognitionRequest.append is thread-safe.
    private nonisolated static func installAudioTap(
        on node: AVAudioInputNode,
        format: AVAudioFormat,
        request: SFSpeechAudioBufferRecognitionRequest
    ) {
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    public func startListening() {
        guard !isListening else { return }

        let locale = Locale(identifier: preferences.speechInputLanguage)
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            errorMessage = L.micUnavailable
            return
        }
        guard recognizer.isAvailable else {
            errorMessage = L.micRecognizerBusy
            return
        }

        self.recognizer = recognizer
        self.transcript = ""
        self.errorMessage = nil
        self.userStoppedSession = false

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            errorMessage = L.micNoInputDevice
            cleanup()
            return
        }

        Self.installAudioTap(on: inputNode, format: format, request: req)

        do {
            engine.prepare()
            try engine.start()
        } catch {
            errorMessage = L.micStartFailed(error.localizedDescription)
            cleanup()
            return
        }

        self.audioEngine = engine
        self.request = req
        self.isListening = true

        recognitionTask = Self.startRecognitionTask(
            recognizer: recognizer,
            request: req,
            onPartial: { [weak self] text in
                Task { @MainActor [weak self] in
                    self?.transcript = text
                }
            },
            onFailure: { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !self.userStoppedSession {
                        self.errorMessage = L.micRecognitionFailed(error.localizedDescription)
                    }
                    self.cleanup()
                }
            }
        )
    }

    // SFSpeechRecognizer may deliver recognitionTask callbacks on background queues.
    // Starting the task from a nonisolated helper prevents the closure from inheriting
    // @MainActor isolation and tripping swift_task_checkIsolatedSwift. Results are
    // funneled back to the caller via @Sendable callbacks that explicitly hop to
    // MainActor before touching observable state.
    private nonisolated static func startRecognitionTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onPartial: @escaping @Sendable (String) -> Void,
        onFailure: @escaping @Sendable (Error) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                onPartial(result.bestTranscription.formattedString)
            }
            if let error {
                onFailure(error)
            }
        }
    }

    @discardableResult
    public func stopListening() -> String {
        userStoppedSession = true
        let result = transcript
        cleanup()
        transcript = ""
        return result
    }

    private func cleanup() {
        request?.endAudio()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionTask?.cancel()
        audioEngine = nil
        request = nil
        recognitionTask = nil
        isListening = false
    }
}
