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

public struct BootProgress: Sendable, Equatable {
    public var step: String
    public var detail: String
    public var fraction: Double
    public init(step: String = "Starting…", detail: String = "", fraction: Double = 0) {
        self.step = step; self.detail = detail; self.fraction = fraction
    }
}

@MainActor
@Observable
public final class AppState {
    public var modelState: ModelLifecycle = .cold
    public var chatState: ChatLifecycle = .idle
    public var conversations: [Conversation] = []
    public var activeConversationID: UUID? {
        didSet { _activeIndex = nil }
    }
    public var lastError: AppError?
    public var boot: BootProgress = BootProgress()
    public var modelInfo: ModelInfo?
    public var awaitingFirstToken: Bool = false
    public var contextWindow: ContextWindow?
    public var outOfContextMessageIDs: Set<UUID> = []

    public init() {}

    public var activeConversation: Conversation? {
        guard let id = activeConversationID else { return nil }
        // O(1) via cached index when available, fallback to linear search.
        if let idx = _activeIndex, idx < conversations.count,
           conversations[idx].id == id {
            return conversations[idx]
        }
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return nil }
        _activeIndex = idx
        return conversations[idx]
    }

    /// Cached index — invalidated on conversation mutations.
    var _activeIndex: Int?
}
