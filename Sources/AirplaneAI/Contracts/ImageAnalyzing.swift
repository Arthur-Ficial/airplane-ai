import AppKit

public protocol ImageAnalyzing: Sendable {
    func analyze(_ image: NSImage) async throws -> String
}
