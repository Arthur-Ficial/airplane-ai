import SwiftUI

struct MicButton: View {
    let speechInput: LiveSpeechInput
    let onTranscript: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button { toggle() } label: {
            ZStack {
                if speechInput.isListening {
                    pulseRing
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: "mic")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: Metrics.Size.sendButton, height: Metrics.Size.sendButton)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(buttonHelpText)
        .accessibilityLabel(speechInput.isListening ? L.micStopRecording : L.micVoiceInput)
    }

    @ViewBuilder
    private var pulseRing: some View {
        if reduceMotion {
            Circle()
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
        } else {
            Circle()
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulseScale = 1.3
                    }
                }
                .onDisappear { pulseScale = 1.0 }
        }
    }

    private func toggle() {
        if speechInput.isListening {
            let text = speechInput.stopListening()
            if !text.isEmpty { onTranscript(text) }
        } else {
            Task {
                speechInput.errorMessage = nil
                let ok = await speechInput.requestPermissions()
                guard ok else {
                    speechInput.errorMessage = L.micPermissionDenied
                    return
                }
                speechInput.startListening()
            }
        }
    }

    private var buttonHelpText: String {
        if let errorMessage = speechInput.errorMessage, !speechInput.isListening {
            return errorMessage
        }
        return speechInput.isListening ? L.micStopRecording : L.micVoiceInput
    }
}
