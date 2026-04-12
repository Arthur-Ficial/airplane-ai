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
