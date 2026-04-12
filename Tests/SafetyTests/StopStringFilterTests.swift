import Foundation
import Testing
@testable import AirplaneAI

// Pure helpers that exercise OutputSanitizer.stripLeakingMarkers on sample strings.
// These model the live behavior we need from LlamaSwiftEngine's tail scanner.
@Suite("Stop-string filter")
struct StopStringFilterTests {
    @Test func stripsFullImStart() {
        let (clean, hit) = OutputSanitizer.stripLeakingMarkers("hello world<|im_start|>")
        #expect(clean == "hello world")
        #expect(hit)
    }

    @Test func stripsPartialImStartWithoutClosing() {
        // The model emitted '<|im_start' without the trailing '|>' — must still stop.
        let (clean, hit) = OutputSanitizer.stripLeakingMarkers("Let me know!  I'm ready.\n<|im_start")
        #expect(clean == "Let me know!  I'm ready.\n")
        #expect(hit)
    }

    @Test func stripsPartialFileSeparator() {
        let (clean, hit) = OutputSanitizer.stripLeakingMarkers("done <|file_sep")
        #expect(clean == "done ")
        #expect(hit)
    }

    @Test func passesThroughCleanText() {
        let (clean, hit) = OutputSanitizer.stripLeakingMarkers("This is regular prose. With <html> brackets.")
        #expect(clean == "This is regular prose. With <html> brackets.")
        #expect(!hit)
    }

    @Test func preservesLoneLessThanPipe() {
        // A bare "<|" mid-sentence is not a marker leak — keep it.
        let (clean, hit) = OutputSanitizer.stripLeakingMarkers("x <| y") // ambiguous but no known-opener match
        #expect(clean == "x <| y")
        #expect(!hit)
    }
}
