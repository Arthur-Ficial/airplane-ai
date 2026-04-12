import Foundation
import Observation

public enum ModelLifecycle: Equatable, Sendable {
    case cold
    case verifyingModel
    case loadingModel
    case warmingModel
    case ready
    case unloading
    case blockedInsufficientResources(AppError)
    case modelMissing
    case modelCorrupt
    case loadFailed(String)
    case migrationFailed
}

public enum ChatLifecycle: Equatable, Sendable {
    case idle, generating, cancelling
}

@MainActor
@Observable
public final class AppState {
    public var modelState: ModelLifecycle = .cold
    public var chatState: ChatLifecycle = .idle
    public var conversations: [Conversation] = []
    public var activeConversationID: UUID?
    public var lastError: AppError?

    public init() {}

    public var activeConversation: Conversation? {
        guard let id = activeConversationID else { return nil }
        return conversations.first { $0.id == id }
    }
}
