import Foundation

// Spec §12.4: stop on repetitive output / whitespace runs / over-length.
public final class OutputSanitizer: @unchecked Sendable {
    public let maxOutputTokens: Int
    public let maxRepeatTokenID: Int          // same tokenID N times in a row
    public let maxRepeatLine: Int             // same line N times in a row
    public let maxWhitespaceRun: Int          // consecutive whitespace-only tokens

    private var lastTokenID: Int32?
    private var repeatCount = 0
    private var lines: [String] = []
    private var currentLine = ""
    private var lineRepeats = 0
    private var lastLine: String?
    private var whitespaceRun = 0
    private var totalTokens = 0

    public init(
        maxOutputTokens: Int = 4096,
        maxRepeatTokenID: Int = 64,
        maxRepeatLine: Int = 4,
        maxWhitespaceRun: Int = 64
    ) {
        self.maxOutputTokens = maxOutputTokens
        self.maxRepeatTokenID = maxRepeatTokenID
        self.maxRepeatLine = maxRepeatLine
        self.maxWhitespaceRun = maxWhitespaceRun
    }

    public func check(_ chunk: TokenChunk) -> StopReason? {
        totalTokens += 1
        if totalTokens > maxOutputTokens { return .outputTooLong }

        // Token-ID repetition.
        if let id = chunk.tokenID {
            if lastTokenID == id { repeatCount += 1 } else { repeatCount = 1 }
            lastTokenID = id
            if repeatCount >= maxRepeatTokenID { return .repetitiveOutput }
        }

        // Whitespace run.
        if chunk.text.allSatisfy({ $0.isWhitespace }) {
            whitespaceRun += 1
            if whitespaceRun >= maxWhitespaceRun { return .whitespaceRun }
        } else {
            whitespaceRun = 0
        }

        // Line repetition.
        for ch in chunk.text {
            if ch.isNewline {
                let line = currentLine
                if line == lastLine { lineRepeats += 1 } else { lineRepeats = 1 }
                lastLine = line
                if lineRepeats >= maxRepeatLine { return .repetitiveOutput }
                currentLine = ""
            } else {
                currentLine.append(ch)
            }
        }
        return nil
    }
}
