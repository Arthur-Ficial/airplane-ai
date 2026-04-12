import SwiftUI

// Reusable icon-only action button with hover affordance.
// Secondary tint by default, accent on hover.
struct IconActionButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.medium))
                .foregroundStyle(hover ? Palette.accent : .secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
