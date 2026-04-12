import SwiftUI

// Circular send button.
// Idle + canSend: accent fill, white up-arrow.
// Generating, no token yet: accent fill, inline ProgressView spinner.
// Generating, streaming: accent fill, white stop icon.
// Disabled: bordered outline, secondary arrow.
struct SendButton: View {
    let generating: Bool
    let canSend: Bool
    let awaitingFirstToken: Bool
    let onTap: () -> Void

    init(generating: Bool, canSend: Bool, awaitingFirstToken: Bool = false, onTap: @escaping () -> Void) {
        self.generating = generating
        self.canSend = canSend
        self.awaitingFirstToken = awaitingFirstToken
        self.onTap = onTap
    }

    var body: some View {
        let active = canSend || generating
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(active ? Palette.accent : Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        Circle().strokeBorder(
                            active ? Color.clear : Color(nsColor: .separatorColor),
                            lineWidth: 1
                        )
                    )
                    .frame(width: Metrics.Size.sendButton, height: Metrics.Size.sendButton)

                if generating && awaitingFirstToken {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    Image(systemName: generating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(active ? Color.white : Color.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!active)
        .help(generating ? L.actionStop : L.actionSend)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
