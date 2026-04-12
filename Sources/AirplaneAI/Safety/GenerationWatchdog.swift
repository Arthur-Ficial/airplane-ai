import Foundation

// Spec §12.5: enforce time-to-first-token + max silent gap.
public actor GenerationWatchdog {
    public let ttftBudget: Duration
    public let silentGapBudget: Duration

    private var startedAt: ContinuousClock.Instant?
    private var lastToken: ContinuousClock.Instant?
    private var firstTokenSeen = false

    public init(ttftBudget: Duration = .seconds(30), silentGapBudget: Duration = .seconds(20)) {
        self.ttftBudget = ttftBudget
        self.silentGapBudget = silentGapBudget
    }

    public func start() {
        let now = ContinuousClock.now
        startedAt = now
        lastToken = now
        firstTokenSeen = false
    }

    public func recordToken() {
        lastToken = ContinuousClock.now
        firstTokenSeen = true
    }

    // Returns .stalled if a budget is exceeded, otherwise nil.
    public func check() -> StopReason? {
        let now = ContinuousClock.now
        if !firstTokenSeen {
            if let s = startedAt, now - s > ttftBudget { return .stalled }
        } else if let lt = lastToken, now - lt > silentGapBudget {
            return .stalled
        }
        return nil
    }
}
