import Foundation
@testable import AirplaneAI

@MainActor
final class MockLiveSpeechInput: LiveSpeechInputting {
    var isListening = false
    var transcript = ""
    var errorMessage: String?
    var scriptedTranscript = "Hello world"

    func requestPermissions() async -> Bool { true }

    func startListening() {
        isListening = true
        transcript = ""
    }

    func stopListening() -> String {
        isListening = false
        let result = scriptedTranscript
        transcript = ""
        return result
    }
}
