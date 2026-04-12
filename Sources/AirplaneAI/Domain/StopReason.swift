import Foundation

public enum StopReason: String, Sendable, Codable, CaseIterable {
    case completed
    case cancelledByUser
    case contextLimitReached
    case repetitiveOutput
    case whitespaceRun
    case outputTooLong
    case stalled
    case lowMemory
    case lowDisk
    case interruptedByLifecycle
    case engineError
}
