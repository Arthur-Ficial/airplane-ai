import Foundation
import SwiftUI
import Testing
@testable import AirplaneAI

@Suite("Inline code pill styling")
struct InlineCodeStylingTests {
    @Test func inlineCodeRunGetsPaletteBackgroundLight() {
        let attr = MarkdownRenderer.render("use `npm install`", scheme: .light)
        var sawCodeRun = false
        for run in attr.runs where run.inlinePresentationIntent == .code {
            sawCodeRun = true
            // Must have a SwiftUI background color applied.
            #expect(run.backgroundColor != nil, "inline code run must have a background")
            #expect(run.foregroundColor != nil, "inline code run must have a foreground color")
        }
        #expect(sawCodeRun, "expected at least one .code run in the rendered output")
    }

    @Test func inlineCodeRunGetsPaletteBackgroundDark() {
        let attr = MarkdownRenderer.render("run `git status`", scheme: .dark)
        var sawCodeRun = false
        for run in attr.runs where run.inlinePresentationIntent == .code {
            sawCodeRun = true
            #expect(run.backgroundColor != nil)
            #expect(run.foregroundColor != nil)
        }
        #expect(sawCodeRun)
    }

    @Test func nonCodeRunIsUnstyled() {
        let attr = MarkdownRenderer.render("plain text", scheme: .light)
        for run in attr.runs where run.inlinePresentationIntent != .code {
            #expect(run.backgroundColor == nil, "non-code runs must not get the pill bg")
        }
    }
}
