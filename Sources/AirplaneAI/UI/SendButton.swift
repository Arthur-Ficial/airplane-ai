import SwiftUI

// Circular send button.
// Enabled = accent-filled + white arrow; disabled = subtle bordered outline.
struct SendButton: View {
    let generating: Bool
    let canSend: Bool
    let onTap: () -> Void

    var body: some View {
        let active = canSend || generating
        Button(action: onTap) {
            Image(systemName: generating ? "stop.fill" : "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.secondary)
                .frame(width: Metrics.Size.sendButton, height: Metrics.Size.sendButton)
                .background(
                    Circle().fill(active ? Palette.accent : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Circle().strokeBorder(active ? Color.clear : Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!active)
        .help(generating ? L.actionStop : L.actionSend)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
