import SwiftUI

// Sidebar: search + select + rename + delete. Mirrors apfel-chat pattern.
struct ConversationListView: View {
    let state: AppState
    let controller: ConversationController
    @AppStorage("airplane.timeFormat") private var timeFormat: String = "relative"

    @State private var search: String = ""
    @State private var editingId: UUID?
    @State private var editTitle: String = ""
    @State private var cachedFiltered: [Conversation] = []
    @FocusState private var searchFocused: Bool

    var body: some View {
        List(selection: Binding(
            get: { state.activeConversationID },
            set: { if let id = $0 { controller.select(id: id) } }
        )) {
            ForEach(cachedFiltered) { conv in
                row(for: conv).tag(conv.id as UUID?)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $search, placement: .sidebar, prompt: "Search")
        .searchFocused($searchFocused)
        .onReceive(NotificationCenter.default.publisher(for: .airplaneFocusSearch)) { _ in
            searchFocused = true
        }
        .onChange(of: search) { _, _ in refilter() }
        .onChange(of: state.conversations) { _, _ in refilter() }
        .onAppear { refilter() }
        .navigationTitle(L.sidebarTitle)
        .toolbar {
            ToolbarItem {
                Button(action: controller.newConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .help(L.actionNewChat)
                .accessibilityLabel(L.actionNewChat)
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // Debounced: only refilter when search text or conversation count changes.
    private func refilter() {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { cachedFiltered = state.conversations; return }
        cachedFiltered = state.conversations.filter { $0.title.lowercased().contains(q) }
    }

    @ViewBuilder
    private func row(for conv: Conversation) -> some View {
        if editingId == conv.id {
            TextField("Title", text: $editTitle)
                .textFieldStyle(.plain)
                .onSubmit { commitEdit(for: conv) }
                .onExitCommand { editingId = nil }
        } else {
            let cleanTitle = OutputSanitizer.stripTrailingFragments(conv.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanTitle.isEmpty ? L.actionNewChat : cleanTitle)
                    .font(.body).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(conv.messages.count) msg\(conv.messages.count == 1 ? "" : "s")")
                    Text("·")
                    timestampText(conv.updatedAt)
                }
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .contextMenu {
                Button(L.actionRename) {
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
