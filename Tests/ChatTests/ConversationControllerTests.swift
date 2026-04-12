import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("ConversationController")
struct ConversationControllerTests {
    @Test func loadAllPopulatesState() async throws {
        let state = AppState()
        let store = MockConversationStore()
        try await store.save(Conversation(title: "A"))
        try await store.save(Conversation(title: "B"))
        let c = ConversationController(state: state, store: store)
        await c.loadAll()
        #expect(state.conversations.count == 2)
        #expect(state.activeConversationID != nil)
    }

    @Test func newConversationBecomesActive() async {
        let state = AppState()
        let store = MockConversationStore()
        let c = ConversationController(state: state, store: store)
        c.newConversation()
        #expect(state.conversations.count == 1)
        #expect(state.activeConversationID == state.conversations.first?.id)
    }

    @Test func deleteRemovesAndReassignsActive() async throws {
        let state = AppState()
        let store = MockConversationStore()
        let c = ConversationController(state: state, store: store)
        c.newConversation()
        // Put a message into the first chat so the debounce lets us create a second.
        state.conversations[0].messages.append(ChatMessage(role: .user, content: "hi"))
        c.newConversation()
        let first = state.conversations[0].id
        await c.delete(id: first)
        #expect(state.conversations.count == 1)
        #expect(state.activeConversationID == state.conversations.first?.id)
    }

    @Test func renameUpdatesTitleAndPersists() async throws {
        let state = AppState()
        let store = MockConversationStore()
        let c = ConversationController(state: state, store: store)
        c.newConversation()
        let id = state.conversations[0].id
        await c.rename(id: id, to: "  My Cool Chat  ")
        #expect(state.conversations[0].title == "My Cool Chat")
        let saved = try await store.conversation(id: id)
        #expect(saved?.title == "My Cool Chat")
    }

    @Test func newConversationDebouncedWhenActiveIsEmpty() async throws {
        let state = AppState()
        let store = MockConversationStore()
        let c = ConversationController(state: state, store: store)
        c.newConversation()
        c.newConversation()
        c.newConversation()
        // Three rapid taps should produce just one empty conversation.
        #expect(state.conversations.count == 1)
    }

    @Test func renameEmptyTitleFallsBackToNewChat() async throws {
        let state = AppState()
        let store = MockConversationStore()
        let c = ConversationController(state: state, store: store)
        c.newConversation()
        let id = state.conversations[0].id
        await c.rename(id: id, to: "   ")
        #expect(state.conversations[0].title == "New Chat")
    }
}
