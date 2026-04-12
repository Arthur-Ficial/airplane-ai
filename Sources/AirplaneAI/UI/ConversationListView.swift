import SwiftUI

// Apfel-chat port: search + rename + delete + instant selection.
struct ConversationListView: View {
    let state: AppState
    let controller: ConversationController
    @AppStorage("airplane.timeFormat") private var timeFormat: String = "relative"

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
                .onExitCommand { editingId = nil }
                .tag(conv.id as UUID?)
        } else {
            let cleanTitle = OutputSanitizer.stripLeakingMarkers(conv.title).0
                .trimmingCharacters(in: .whitespacesAndNewlines)
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanTitle.isEmpty ? "New Chat" : cleanTitle)
                    .font(.body).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(conv.messages.count) msg\(conv.messages.count == 1 ? "" : "s")")
                    Text("·")
                    timestampText(conv.updatedAt)
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .tag(conv.id as UUID?)
            .onTapGesture(count: 2) {
                editTitle = conv.title
                editingId = conv.id
            }
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
        let newTitle = editTitle
        editingId = nil
        Task { await controller.rename(id: conv.id, to: newTitle) }
    }

    @ViewBuilder
    private func timestampText(_ date: Date) -> some View {
        if timeFormat == "absolute" {
            Text(date, format: .dateTime.month(.abbreviated).day().hour().minute())
        } else {
            Text(date, format: .relative(presentation: .numeric))
        }
    }
}
