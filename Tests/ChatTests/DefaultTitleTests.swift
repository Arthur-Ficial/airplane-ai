import Foundation
import Testing
@testable import AirplaneAI

@Suite("ChatController.isDefaultTitle")
struct DefaultTitleTests {
    @Test @MainActor func nilIsDefault() { #expect(ChatController.isDefaultTitle(nil)) }
    @Test @MainActor func emptyIsDefault() { #expect(ChatController.isDefaultTitle("")) }
    @Test @MainActor func whitespaceIsDefault() { #expect(ChatController.isDefaultTitle("   \n")) }
    @Test @MainActor func newChatIsDefault() { #expect(ChatController.isDefaultTitle("New Chat")) }
    @Test @MainActor func newChatWithWhitespaceIsDefault() { #expect(ChatController.isDefaultTitle("  New Chat  ")) }
    @Test @MainActor func customTitleIsNotDefault() { #expect(!ChatController.isDefaultTitle("Austria trip plan")) }
    @Test @MainActor func derivedTitleIsNotDefault() { #expect(!ChatController.isDefaultTitle("What is the c…")) }
}
