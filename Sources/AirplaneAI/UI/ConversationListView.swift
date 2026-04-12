import SwiftUI

struct ConversationListView: View {
    let state: AppState
    let controller: ConversationController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: "sidebar.title"))
                    .font(.headline)
                Spacer()
                Button(action: controller.newConversation) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "action.new_chat"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Divider()
            List(selection: Binding(
                get: { state.activeConversationID },
                set: { if let id = $0 { controller.select(id: id) } }
            )) {
                ForEach(state.conversations) { c in
                    Text(c.title).tag(c.id as UUID?)
                        .contextMenu {
                            Button(String(localized: "action.delete"), role: .destructive) {
                                Task { await controller.delete(id: c.id) }
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }
}
