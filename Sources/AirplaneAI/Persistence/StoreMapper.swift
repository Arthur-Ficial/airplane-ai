import Foundation

// Explicit mapping between domain types and SwiftData models.
// Spec §13: domain stays framework-free; mapping is visible, testable, SSOT.
enum StoreMapper {
    static func toDomain(_ sc: StoredConversation) -> Conversation {
        let messages = sc.messages
            .sorted { $0.createdAt < $1.createdAt }
            .map(toDomain)
        return Conversation(
            id: sc.id,
            title: sc.title,
            messages: messages,
            createdAt: sc.createdAt,
            updatedAt: sc.updatedAt
        )
    }

    static func toDomain(_ sm: StoredMessage) -> ChatMessage {
        ChatMessage(
            id: sm.id,
            role: MessageRole(rawValue: sm.role) ?? .user,
            content: sm.content,
            createdAt: sm.createdAt,
            status: MessageStatus(rawValue: sm.status) ?? .complete,
            stopReason: sm.stopReason.flatMap { StopReason(rawValue: $0) }
        )
    }

    static func update(_ sc: StoredConversation, from c: Conversation) {
        sc.title = c.title
        sc.updatedAt = c.updatedAt
        // Replace message set via id-match; we overwrite rather than diff.
        let existing = Dictionary(uniqueKeysWithValues: sc.messages.map { ($0.id, $0) })
        var incomingIDs = Set<UUID>()
        for m in c.messages {
            incomingIDs.insert(m.id)
            if let sm = existing[m.id] {
                sm.content = m.content
                sm.status = m.status.rawValue
                sm.stopReason = m.stopReason?.rawValue
            } else {
                let sm = StoredMessage(
                    id: m.id, role: m.role.rawValue, content: m.content,
                    createdAt: m.createdAt, status: m.status.rawValue,
                    stopReason: m.stopReason?.rawValue
                )
                sm.conversation = sc
                sc.messages.append(sm)
            }
        }
        sc.messages.removeAll { !incomingIDs.contains($0.id) }
    }

    static func makeStored(from c: Conversation) -> StoredConversation {
        let sc = StoredConversation(id: c.id, title: c.title, createdAt: c.createdAt, updatedAt: c.updatedAt)
        for m in c.messages {
            let sm = StoredMessage(
                id: m.id, role: m.role.rawValue, content: m.content,
                createdAt: m.createdAt, status: m.status.rawValue,
                stopReason: m.stopReason?.rawValue
            )
            sm.conversation = sc
            sc.messages.append(sm)
        }
        return sc
    }
}
