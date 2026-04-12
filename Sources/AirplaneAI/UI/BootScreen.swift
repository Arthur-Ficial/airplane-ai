import SwiftUI

struct BootScreen: View {
    let state: AppState
    @State private var tick: Int = 0
    @State private var displayedFraction: Double = 0

    private let rotatingDetails = [
        "checking memory",
        "checking disk",
        "verifying model integrity",
        "memory-mapping GGUF",
        "initializing Metal backend",
        "loading vocabulary",
        "allocating KV cache",
        "running warmup pass",
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            AirplaneGlyph(size: Metrics.Size.airplaneGlyphLarge)
            Text("Airplane AI").font(.largeTitle.weight(.semibold))
            Text(L.tagline).font(.callout).foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ProgressView(value: displayedFraction)
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .animation(.easeInOut(duration: 0.25), value: displayedFraction)

                VStack(spacing: 3) {
                    Text(state.boot.step).font(.callout.weight(.medium))
                    Text(currentDetail).font(.caption).foregroundStyle(.secondary).monospaced()
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 420)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bootBackground)
        .onAppear { startTicker() }
        .onChange(of: state.boot.fraction) { _, new in
            withAnimation(.easeInOut(duration: 0.3)) { displayedFraction = new }
        }
    }

    private var currentDetail: String {
        if !state.boot.detail.isEmpty { return state.boot.detail }
        // Fallback rotating ticker so the user always sees motion.
        return rotatingDetails[tick % rotatingDetails.count]
    }

    private func startTicker() {
        // Advance until the app is ready; SwiftUI auto-cancels the task when the view disappears.
        Task { @MainActor in
            while state.modelState != .ready {
                try? await Task.sleep(nanoseconds: 350_000_000)
                tick += 1
                // Fallback forward motion for the bar — never exceed the real fraction by more than 5%.
                let floor = state.boot.fraction
                if displayedFraction < floor + 0.05 {
                    withAnimation(.linear(duration: 0.35)) {
                        displayedFraction = min(0.95, max(displayedFraction, floor) + 0.02)
                    }
                }
            }
        }
    }

    private var bootBackground: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.06)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
