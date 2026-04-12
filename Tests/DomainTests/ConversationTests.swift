import Foundation
import Testing
@testable import AirplaneAI

@Suite("Conversation")
struct ConversationTests {
    @Test func defaultTitleWhenEmpty() {
        #expect(Conversation.derivedTitle(from: "") == "New Chat")
        #expect(Conversation.derivedTitle(from: "   \n\t") == "New Chat")
    }

    @Test func shortMessageUsedVerbatim() {
        #expect(Conversation.derivedTitle(from: "Hello") == "Hello")
        #expect(Conversation.derivedTitle(from: "  Trim me  ") == "Trim me")
    }

    @Test func longMessageCutOnWordBoundary() {
        let long = "This is a reasonably long first user message that should be truncated"
        let title = Conversation.derivedTitle(from: long)
        #expect(title.count <= 41) // 40 + ellipsis
        #expect(title.hasSuffix("…"))
        #expect(!title.contains("reasonably long first user mes")) // word-boundary cut
    }

    @Test func longNoSpaceFallsBackToHardCut() {
        let glued = String(repeating: "a", count: 100)
        let title = Conversation.derivedTitle(from: glued)
        #expect(title.count == 41)
        #expect(title.hasSuffix("…"))
    }

    @Test func codableRoundTrip() throws {
        var c = Conversation(title: "Hi")
        c.messages = [ChatMessage(role: .user, content: "Hello"), ChatMessage(role: .assistant, content: "World", status: .complete)]
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(Conversation.self, from: data)
        #expect(decoded.id == c.id)
        #expect(decoded.messages.count == 2)
    }
}
