import SwiftUI

// SSOT for the in-app airplane glyph. Boot screen, welcome, about, and chat
// welcome all display the same PNG. Source artwork lives at
// branding/airplane-ai-transparent.png and is bundled as AppIconGlyph.png.
struct AirplaneGlyph: View {
    var size: CGFloat = Metrics.Size.airplaneGlyphLarge

    var body: some View {
        Image("AppIconGlyph", bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
