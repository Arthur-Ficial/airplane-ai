import AVFoundation
import Foundation

@MainActor
public final class SpeechOutput {
    private let synthesizer = AVSpeechSynthesizer()
    private let preferences: AudioPreferences

    public init(preferences: AudioPreferences) {
        self.preferences = preferences
    }

    public func speak(_ text: String) {
        guard preferences.speechOutputEnabled, !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice(for: preferences.speechOutputLanguage)
            ?? AVSpeechSynthesisVoice(language: preferences.speechOutputLanguage)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func preferredVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let voices = preferences.catalog.voices
        guard let identifier = AudioLanguageCatalog.preferredVoiceIdentifier(
            for: languageCode,
            availableVoices: voices
        ) else {
            return nil
        }
        return AVSpeechSynthesisVoice(identifier: identifier)
    }
}
