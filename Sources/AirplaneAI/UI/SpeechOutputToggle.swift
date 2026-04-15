import SwiftUI

struct SettingsCircleButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.secondary)
                .frame(width: 30, height: 30)
                .aspectRatio(1, contentMode: .fit)
                .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help("Settings (⌘,)")
        .accessibilityLabel("Open Settings")
    }
}

struct SpeechOutputToggle: View {
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            Image(systemName: isEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                .frame(width: 30, height: 30)
                .aspectRatio(1, contentMode: .fit)
                .background(
                    Circle().fill(isEnabled ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Circle().strokeBorder(
                        isEnabled ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
        .help(isEnabled ? "Speech output on — click to mute" : "Speech output off — click to speak responses")
        .accessibilityLabel(isEnabled ? "Turn off spoken responses" : "Turn on spoken responses")
    }
}
