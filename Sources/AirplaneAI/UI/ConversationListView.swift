import SwiftUI

// Apfel-chat port: search + rename + delete + instant selection.
struct ConversationListView: View {
    let state: AppState
    let controller: ConversationController

    @State private var search: String = ""
    @State private var editingId: UUID?
    @State private var editTitle: String = ""

    var body: some View {
        List(selection: Binding(
            get: { state.activeConversationID },
            set: { if let id = $0 { controller.select(id: id) } }
        )) {
            ForEach(filtered) { conv in
                row(for: conv)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $search, placement: .sidebar, prompt: "Search")
        .navigationTitle(L.sidebarTitle)
        .toolbar {
            ToolbarItem {
                Button(action: controller.newConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .help(L.actionNewChat)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    private var filtered: [Conversation] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return state.conversations }
        return state.conversations.filter {
            $0.title.lowercased().contains(q)
            || $0.messages.contains { $0.content.lowercased().contains(q) }
        }
    }

    @ViewBuilder
    private func row(for conv: Conversation) -> some View {
        if editingId == conv.id {
            TextField("Title", text: $editTitle)
                .textFieldStyle(.plain)
                .onSubmit { commitEdit(for: conv) }
                .tag(conv.id as UUID?)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text(conv.title.isEmpty ? "New Chat" : conv.title)
                    .font(.body).lineLimit(1)
                Text(conv.updatedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .tag(conv.id as UUID?)
            .contextMenu {
                Button("Rename") {
                    editTitle = conv.title
                    editingId = conv.id
                }
                Divider()
                Button(L.actionDelete, role: .destructive) {
                    Task { await controller.delete(id: conv.id) }
                }
            }
        }
    }

    private func commitEdit(for conv: Conversation) {
        if let idx = state.conversations.firstIndex(where: { $0.id == conv.id }) {
            state.conversations[idx].title = editTitle.isEmpty ? "New Chat" : editTitle
            state.conversations[idx].updatedAt = .now
            let updated = state.conversations[idx]
            Task.detached { /* best-effort persist — ChatController handles the store */
                _ = updated
            }
        }
        editingId = nil
    }
}
