import Foundation
import Testing
@testable import AirplaneAI

@Suite("OutputSanitizer")
struct OutputSanitizerTests {
    @Test func stopsOnRepeatTokenID() {
        let s = OutputSanitizer(maxRepeatTokenID: 3)
        var out: StopReason?
        for _ in 0..<10 {
            out = s.check(TokenChunk(text: "x", tokenID: 42, index: 0))
            if out != nil { break }
        }
        #expect(out == .repetitiveOutput)
    }

    @Test func stopsOnWhitespaceRun() {
        let s = OutputSanitizer(maxWhitespaceRun: 3)
        var out: StopReason?
        for i in 0..<10 {
            out = s.check(TokenChunk(text: "  ", tokenID: Int32(i), index: i))
            if out != nil { break }
        }
        #expect(out == .whitespaceRun)
    }

    @Test func stopsOnRepeatedLine() {
        let s = OutputSanitizer(maxRepeatLine: 3)
        var out: StopReason?
        for i in 0..<6 {
            out = s.check(TokenChunk(text: "hello\n", tokenID: Int32(i), index: i))
            if out != nil { break }
        }
        #expect(out == .repetitiveOutput)
    }

    @Test func stopsOnOutputTooLong() {
        let s = OutputSanitizer(maxOutputTokens: 5)
        var out: StopReason?
        for i in 0..<10 {
            out = s.check(TokenChunk(text: "a", tokenID: Int32(i), index: i))
            if out != nil { break }
        }
        #expect(out == .outputTooLong)
    }

    @Test func passesHealthyStream() {
        let s = OutputSanitizer()
        let texts = ["Hello", " ", "world", "!"]
        for (i, t) in texts.enumerated() {
            #expect(s.check(TokenChunk(text: t, tokenID: Int32(i * 100), index: i)) == nil)
        }
    }
}
