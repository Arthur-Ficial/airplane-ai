import Foundation
import os

public enum AirLog {
    public enum Category: String { case inference, memory, storage, lifecycle, safety, ui, migration }

    private static func logger(_ c: Category) -> Logger {
        Logger(subsystem: "com.franzai.airplane-ai", category: c.rawValue)
    }

    public static func debug(_ message: String, category: Category = .lifecycle) {
        #if AIRPLANE_DEBUG
        logger(category).debug("\(message, privacy: .public)")
        #endif
    }

    public static func info(_ message: String, category: Category = .lifecycle) {
        logger(category).info("\(message, privacy: .public)")
    }

    public static func error(_ message: String, category: Category = .lifecycle) {
        logger(category).error("\(message, privacy: .public)")
    }

    // Verbose content logging: gated by a second flag; never CI, never release.
    public static func content(_ message: String, category: Category = .inference) {
        #if AIRPLANE_DEBUG && AIRPLANE_DEBUG_VERBOSE_CONTENT
        logger(category).debug("[content] \(message, privacy: .private)")
        #endif
    }
}
