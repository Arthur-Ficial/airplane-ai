import AVFoundation
import Foundation

@MainActor
@Observable
public final class SpeechOutput {
    public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.defaultsKey)
            if !isEnabled { synthesizer.stopSpeaking(at: .immediate) }
        }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private static let defaultsKey = "airplane.speechOutputEnabled"

    public init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    public func speak(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
