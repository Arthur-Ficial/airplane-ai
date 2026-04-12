import SwiftUI

// SSOT for layout metrics. Every padding/radius/duration comes from here.
enum Metrics {
    enum Padding {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let regular: CGFloat = 12
        static let large: CGFloat = 16
    }
    enum Radius {
        static let small: CGFloat = 8
        static let regular: CGFloat = 10
        static let bubble: CGFloat = 18
        static let circle: CGFloat = 18   // diameter/2 of the 36pt send button
    }
    enum Size {
        static let sendButton: CGFloat = 30        // tighter than before
        static let statusDot: CGFloat = 8
        static let airplaneGlyphSmall: CGFloat = 24
        static let airplaneGlyphLarge: CGFloat = 44
    }
    enum Duration {
        static let quickAnimation: Double = 0.12
        static let standardAnimation: Double = 0.2
        static let streamFlushMillis: Int = 16     // 60 fps UI batch flush
    }
    enum Bubble {
        static let horizontalInset: CGFloat = 16
        static let userInset: CGFloat = 60
        static let innerPadding: CGFloat = 10
    }
}
