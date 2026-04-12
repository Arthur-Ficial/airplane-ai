import SwiftUI

// Milestone-1 stub. Full layout arrives in M7.
struct RootWindow: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Airplane AI")
                .font(.largeTitle.weight(.semibold))
            Text("AI that never phones home.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(40)
    }
}
