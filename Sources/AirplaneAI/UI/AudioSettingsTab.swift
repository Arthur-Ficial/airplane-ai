import SwiftUI

struct AudioSettingsTab: View {
    let audioPreferences: AudioPreferences?
    @State private var languageQuery = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHero {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L.audioTabTitle).font(.title3.weight(.semibold))
                            Text(L.audioHeroSubtitle)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let audioPreferences {
                    SettingsCard(title: L.audioOutputTitle, subtitle: L.audioOutputSubtitle) {
                        Toggle(L.audioOutputToggle, isOn: outputEnabledBinding(for: audioPreferences))
                            .toggleStyle(.switch)
                    }

                    languageCard(
                        title: L.audioLanguageTitle,
                        subtitle: L.audioLanguageSubtitle,
                        query: $languageQuery,
                        options: filtered(
                            audioPreferences.audioLanguageOptions,
                            query: languageQuery
                        ),
                        selectedID: audioPreferences.audioLanguageSelectionID,
                        onSelect: { audioPreferences.selectAudioLanguage($0) }
                    )
                } else {
                    SettingsCard(title: L.audioTabTitle) {
                        Text("Audio settings are unavailable until the app finishes booting.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private func outputEnabledBinding(for preferences: AudioPreferences) -> Binding<Bool> {
        Binding(
            get: { preferences.speechOutputEnabled },
            set: { preferences.speechOutputEnabled = $0 }
        )
    }

    private func filtered(_ options: [AudioLanguageOption], query: String) -> [AudioLanguageOption] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return options
        }
        return options.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
            || $0.subtitle.localizedCaseInsensitiveContains(query)
            || $0.id.localizedCaseInsensitiveContains(query)
        }
    }

    private func languageCard(
        title: String,
        subtitle: String,
        query: Binding<String>,
        options: [AudioLanguageOption],
        selectedID: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        SettingsCard(title: title, subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                TextField(L.audioSearchPlaceholder, text: query)
                    .textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(options) { option in
                            Button {
                                onSelect(option.id)
                            } label: {
                                languageRow(option, selected: option.id == selectedID)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func languageRow(_ option: AudioLanguageOption, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Palette.accent : Color.secondary.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text(option.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text(option.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if option.hasSiriVoice {
                Text(L.audioBestVoiceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selected ? Palette.accent.opacity(0.10) : Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(selected ? Palette.accent.opacity(0.35) : Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
