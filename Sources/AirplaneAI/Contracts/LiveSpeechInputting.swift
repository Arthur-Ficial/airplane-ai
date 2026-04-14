import Foundation

@MainActor
public protocol LiveSpeechInputting: AnyObject {
    var isListening: Bool { get }
    var transcript: String { get }
    var errorMessage: String? { get }
    func requestPermissions() async -> Bool
    func startListening()
    func stopListening() -> String
}
