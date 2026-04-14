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

    private let recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    public init(locale: Locale = .current) {
        let r = SFSpeechRecognizer(locale: locale)
        self.recognizer = r
        if r == nil || !(r?.supportsOnDeviceRecognition ?? false) {
            errorMessage = L.micUnavailable
        }
    }

    public func requestPermissions() async -> Bool {
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if audioStatus == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted { return false }
        } else if audioStatus != .authorized {
            return false
        }

        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .notDetermined {
            let granted = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
            if !granted { return false }
        } else if speechStatus != .authorized {
            return false
        }

        return true
    }

    public func startListening() {
        guard let recognizer, !isListening else { return }

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true
        req.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        self.audioEngine = engine
        self.request = req
        self.transcript = ""
        self.isListening = true

        recognitionTask = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error, self.isListening {
                    self.errorMessage = error.localizedDescription
                    _ = self.stopListening()
                }
            }
        }
    }

    @discardableResult
    public func stopListening() -> String {
        request?.endAudio()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        recognitionTask?.cancel()

        audioEngine = nil
        request = nil
        recognitionTask = nil
        isListening = false

        let result = transcript
        transcript = ""
        return result
    }
}
