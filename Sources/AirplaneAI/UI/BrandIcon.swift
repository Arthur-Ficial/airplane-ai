import SwiftUI

// SSOT for the airplane glyph. Boot screen, welcome, about, and icon generator
// all read the same spec.
struct AirplaneGlyph: View {
    var size: CGFloat = Metrics.Size.airplaneGlyphLarge

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.12))
                .frame(width: size * 2.7, height: size * 2.7)
            Image(systemName: "airplane")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Palette.accent)
                .rotationEffect(.degrees(-20))
        }
    }
}
