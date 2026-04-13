import SwiftUI

/// Animated bouncing dots shown while waiting for the first token.
struct TypingIndicator: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .offset(y: phase == i ? -4 : 0)
            }
        }
        .frame(height: 20)
        .onAppear { animate() }
    }

    private func animate() {
        Task { @MainActor in
            while !Task.isCancelled {
                for i in 0..<3 {
                    withAnimation(.easeInOut(duration: 0.25)) { phase = i }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
}
