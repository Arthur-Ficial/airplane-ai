import Foundation
import Testing
@testable import AirplaneAI

@Suite("SpeechTranscriber")
struct SpeechTranscriberTests {
    @Test func mockReturnsTranscript() async throws {
        let mock = MockSpeechTranscriber()
        mock.transcript = "Test transcription"
        let result = try await mock.transcribe(URL(fileURLWithPath: "/tmp/test.wav"))
        #expect(result == "Test transcription")
    }

    @Test func mockThrowsWhenConfigured() async {
        let mock = MockSpeechTranscriber()
        mock.shouldThrow = true
        await #expect(throws: AppError.self) {
            _ = try await mock.transcribe(URL(fileURLWithPath: "/tmp/test.wav"))
        }
    }

    @Test func mockReportsAvailability() async {
        let mock = MockSpeechTranscriber()
        #expect(await mock.isAvailable == true)
        mock.available = false
        #expect(await mock.isAvailable == false)
    }

    @Test func audioAttachmentFromTranscript() {
        let attachment = Attachment.audio(transcript: "Hello from speech")
        #expect(attachment.extractedText == "Hello from speech")
        #expect(attachment.extractedText == "Hello from speech")
    }
}
