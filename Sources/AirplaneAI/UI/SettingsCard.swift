import SwiftUI

// SSOT visual container for any Settings section.
// Rounded rect, separator border, optional subtitle.
struct SettingsCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.tertiary) }
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}

// Same visual shell as the Context hero — accent-tinted.
struct SettingsHero<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Palette.accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
            )
    }
}

// Row of pill badges — used for Hardware / Privacy bullets.
struct SettingsBadge: View {
    let icon: String
    let label: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}
