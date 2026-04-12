import Foundation

// SSOT for the effective context window. Reads the bundled manifest's
// app_default_context, clamps to the active RuntimeProfile.defaultContext.
// Every consumer (ContextManager, ChatController cutoff, Settings display,
// toast messaging) must come through here — no duplicate constants.
public struct ContextWindow: Sendable, Equatable {
    public let modelCapability: Int   // 32768 for Gemma-3n-E4B
    public let appDefault: Int        // 8192 from manifest
    public let effective: Int         // min(appDefault, runtimeProfile.defaultContext)

    public init(modelCapability: Int, appDefault: Int, effective: Int) {
        self.modelCapability = modelCapability
        self.appDefault = appDefault
        self.effective = effective
    }

    public static func resolve(manifest: ModelManifest, profile: RuntimeProfile) -> ContextWindow {
        ContextWindow(
            modelCapability: manifest.modelCapabilityContext,
            appDefault: manifest.appDefaultContext,
            effective: min(manifest.appDefaultContext, profile.defaultContext)
        )
    }

    // Compute the out-of-context cutoff index by walking newest→oldest
    // summing each message's estimated token count. Returns the index of
    // the oldest in-context message, or nil if all messages fit.
    public func cutoffIndex(
        messages: [ChatMessage],
        estimatedTokens: (ChatMessage) -> Int
    ) -> Int? {
        var total = 0
        for i in stride(from: messages.count - 1, through: 0, by: -1) {
            total += estimatedTokens(messages[i])
            if total > effective { return i + 1 }
        }
        return nil
    }
}
