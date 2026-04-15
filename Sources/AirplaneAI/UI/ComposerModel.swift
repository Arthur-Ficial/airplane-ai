import Foundation
import Observation

// Owns all composer text state. Lives as a @State of ChatView but its properties
// are only READ inside InputBar's body. That way mutations from live speech
// transcription (10+Hz) invalidate ONLY the composer subtree, not the message
// list — which previously copied every ChatMessage struct on each re-render and
// pegged the main thread.
@Observable
@MainActor
public final class ComposerModel {
    public var draft: String = ""
    public var preListenDraft: String = ""

    public init() {}

    public func prepend(_ text: String) {
        draft = text + draft
    }

    public func captureBeforeListening() {
        preListenDraft = draft
    }

    public func applyLivePartial(_ text: String) {
        guard !text.isEmpty else { return }
        let separator = (preListenDraft.isEmpty || preListenDraft.hasSuffix(" ")) ? "" : " "
        let newDraft = preListenDraft + separator + text
        if newDraft != draft { draft = newDraft }
    }

    public func clear() {
        draft = ""
    }
}
