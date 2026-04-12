import Foundation

@MainActor
public final class ConversationController {
    private let state: AppState
    private let store: any ConversationStore

    public init(state: AppState, store: any ConversationStore) {
        self.state = state
        self.store = store
    }

    public func loadAll() async {
        do {
            state.conversations = try await store.allConversations()
            if state.activeConversationID == nil { state.activeConversationID = state.conversations.first?.id }
        } catch {
            state.lastError = .persistenceFailed(summary: error.localizedDescription)
        }
    }

    public func newConversation() {
        let c = Conversation()
        state.conversations.insert(c, at: 0)
        state.activeConversationID = c.id
        let store = self.store
        Task.detached { try? await store.save(c) }
    }

    public func select(id: UUID) {
        state.activeConversationID = id
    }

    public func delete(id: UUID) async {
        state.conversations.removeAll { $0.id == id }
        if state.activeConversationID == id { state.activeConversationID = state.conversations.first?.id }
        try? await store.delete(id: id)
    }

    public func rename(id: UUID, to title: String) async {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = state.conversations.firstIndex(where: { $0.id == id }) else { return }
        state.conversations[idx].title = clean.isEmpty ? "New Chat" : clean
        state.conversations[idx].updatedAt = .now
        let snapshot = state.conversations[idx]
        try? await store.save(snapshot)
    }
}
