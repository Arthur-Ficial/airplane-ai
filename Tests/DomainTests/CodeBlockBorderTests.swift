import Foundation
import SwiftUI
import Testing
@testable import AirplaneAI

@Suite("Code-block border palette")
struct CodeBlockBorderTests {
    @Test func bordersExistForBothSchemes() {
        // Just asserts the API shape — actual pixel values are visual.
        let light: Color = Palette.codeBlockBorder(.light)
        let dark: Color = Palette.codeBlockBorder(.dark)
        _ = light
        _ = dark
    }
}
