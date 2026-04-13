import Foundation

// Spec §12.4: stop on repetitive output / whitespace runs / over-length.
public final class OutputSanitizer: @unchecked Sendable {
    public let maxOutputTokens: Int
    public let maxRepeatTokenID: Int          // same tokenID N times in a row
    public let maxRepeatLine: Int             // same line N times in a row
    public let maxWhitespaceRun: Int          // consecutive whitespace-only tokens

    // Chat-template control tokens that Gemma / ChatML may emit when the template
    // doesn't wrap the prompt exactly right. Strip from the user-facing stream.
    public static let stopStrings: [String] = [
        "<|file_separator|>",
        "<|im_start|>",
        "<|im_end|>",
        "<|end_of_turn|>",
        "<|start_of_turn|>",
        "<end_of_turn>",
        "<start_of_turn>",
        "<|endoftext|>",
        "<|eot_id|>",
        "<|begin_of_text|>",
    ]

    // Prefixes — caught even when the model truncates the closing "|>".
    // Broad enough to catch partial emissions like "<|im" without "_".
    public static let stopPrefixes: [String] = [
        "<|file",
        "<|im",
        "<|start",
        "<|end",
        "<|system",
        "<|user",
        "<|assistant",
        "<|eot",
        "<|begin",
        "<|pad",
        "<|reserved",
    ]

    // Trailing fragments that appear at the very end when the model hits EOS
    // mid-control-token. These are too short for stopPrefixes but clearly junk.
    private static let trailingJunk: [String] = [
        "<|", "<\n", "< |",
    ]

    /// Strip any trailing control-token fragment from the end of final output.
    public static func stripTrailingFragments(_ text: String) -> String {
        var result = text
        // First strip full markers/prefixes.
        let (cleaned, _) = stripLeakingMarkers(result)
        result = cleaned
        // Then strip short trailing fragments like "<|", "<".
        for junk in trailingJunk {
            if result.hasSuffix(junk) {
                result = String(result.dropLast(junk.count))
            }
        }
        // Final safety: if the text ends with a lone "<", strip it.
        while result.hasSuffix("<") {
            result = String(result.dropLast())
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Returns (cleanTail, true) when a marker appears; otherwise (input, false).
    public static func stripLeakingMarkers(_ text: String) -> (String, Bool) {
        var earliest: String.Index?
        for candidate in stopStrings + stopPrefixes {
            if let r = text.range(of: candidate), earliest == nil || r.lowerBound < earliest! {
                earliest = r.lowerBound
            }
        }
        if let idx = earliest {
            return (String(text[..<idx]), true)
        }
        return (text, false)
    }

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
