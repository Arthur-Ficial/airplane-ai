import SwiftUI

// Apfel-chat-style circular send button.
// Uses dynamic system colors so light/dark are both correct.
struct SendButton: View {
    let generating: Bool
    let canSend: Bool
    let onTap: () -> Void

    var body: some View {
        let active = canSend || generating
        Button(action: onTap) {
            Image(systemName: generating ? "stop.fill" : "arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.gray)
                .frame(width: 36, height: 36)
                .background(active ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .clipShape(Circle())
        }
        .buttonStyle(.borderless)
        .disabled(!active)
        .help(generating ? L.actionStop : L.actionSend)
        .keyboardShortcut(.return, modifiers: .command)
    }
}
