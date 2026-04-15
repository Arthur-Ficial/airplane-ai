import Foundation
import Testing
@testable import AirplaneAI

@MainActor
@Suite("AudioPreferences")
struct AudioPreferencesTests {
    @Test func defaultsPreferCurrentLocaleAndPersist() {
        let defaults = makeDefaults()
        let catalog = sampleCatalog()

        let prefs = AudioPreferences(
            defaults: defaults,
            catalog: catalog,
            currentLocale: Locale(identifier: "de-AT")
        )

        #expect(prefs.speechInputLanguage == "de-DE")
        #expect(prefs.speechOutputLanguage == "de-DE")
        #expect(prefs.speechOutputEnabled == false)

        prefs.speechOutputEnabled = true
        prefs.speechInputLanguage = "fr-FR"
        prefs.speechOutputLanguage = "en-US"

        let reloaded = AudioPreferences(
            defaults: defaults,
            catalog: catalog,
            currentLocale: Locale(identifier: "en-GB")
        )
        #expect(reloaded.speechOutputEnabled == true)
        #expect(reloaded.speechInputLanguage == "fr-FR")
        #expect(reloaded.speechOutputLanguage == "en-US")
    }

    @Test func invalidStoredLanguagesFallBackToSupportedOptions() {
        let defaults = makeDefaults()
        defaults.set("zz-ZZ", forKey: AudioPreferences.inputLanguageKey)
        defaults.set("xx-XX", forKey: AudioPreferences.outputLanguageKey)

        let prefs = AudioPreferences(
            defaults: defaults,
            catalog: sampleCatalog(),
            currentLocale: Locale(identifier: "it-IT")
        )

        #expect(prefs.speechInputLanguage == "en-US")
        #expect(prefs.speechOutputLanguage == "en-US")
    }

    @Test func preferredVoiceIdentifierPrefersSiriThenQuality() {
        let voices = [
            AudioVoiceDescriptor(identifier: "plain", language: "en-US", name: "Plain", qualityRank: 1, isSiri: false),
            AudioVoiceDescriptor(identifier: "premium", language: "en-US", name: "Premium", qualityRank: 2, isSiri: false),
            AudioVoiceDescriptor(identifier: "siri", language: "en-US", name: "Siri Voice 4", qualityRank: 1, isSiri: true),
        ]

        let identifier = AudioLanguageCatalog.preferredVoiceIdentifier(
            for: "en-US",
            availableVoices: voices
        )

        #expect(identifier == "siri")
    }

    @Test func preferredVoiceIdentifierFallsBackToBaseLanguage() {
        let voices = [
            AudioVoiceDescriptor(identifier: "uk-siri", language: "en-GB", name: "Siri Voice 2", qualityRank: 1, isSiri: true),
            AudioVoiceDescriptor(identifier: "fr", language: "fr-FR", name: "French", qualityRank: 1, isSiri: false),
        ]

        let identifier = AudioLanguageCatalog.preferredVoiceIdentifier(
            for: "en-AU",
            availableVoices: voices
        )

        #expect(identifier == "uk-siri")
    }

    @Test func outputOptionsExposeSiriAvailability() {
        let options = sampleCatalog().outputLanguages
        let english = options.first(where: { $0.id == "en-US" })
        let french = options.first(where: { $0.id == "fr-FR" })

        #expect(english?.hasSiriVoice == true)
        #expect(french?.hasSiriVoice == false)
    }

    @Test func selectingOneAudioLanguageUpdatesInputAndOutput() {
        let prefs = AudioPreferences(
            defaults: makeDefaults(),
            catalog: sampleCatalog(),
            currentLocale: Locale(identifier: "en-US")
        )

        prefs.selectAudioLanguage("fr-CA")

        #expect(prefs.speechInputLanguage == "fr-FR")
        #expect(prefs.speechOutputLanguage == "fr-FR")
        #expect(prefs.audioLanguageSelectionID == "fr-FR")
    }

    @Test func audioLanguageOptionsPrioritizeRequestedLanguagesFirst() {
        let catalog = AudioLanguageCatalog(
            inputLanguageIDs: ["it-IT", "en-GB", "de-DE", "en-US", "fr-FR", "en-001"],
            voices: [
                AudioVoiceDescriptor(identifier: "us", language: "en-US", name: "Siri Voice 1", qualityRank: 2, isSiri: true),
                AudioVoiceDescriptor(identifier: "intl", language: "en-001", name: "Siri Voice International", qualityRank: 2, isSiri: true),
                AudioVoiceDescriptor(identifier: "uk", language: "en-GB", name: "Siri Voice 2", qualityRank: 2, isSiri: true),
                AudioVoiceDescriptor(identifier: "de", language: "de-DE", name: "Anna", qualityRank: 1, isSiri: false),
                AudioVoiceDescriptor(identifier: "fr", language: "fr-FR", name: "Thomas", qualityRank: 1, isSiri: false),
            ],
            displayLocale: Locale(identifier: "en-US")
        )

        #expect(Array(catalog.audioLanguages.prefix(4).map(\.id)) == ["en-US", "en-001", "en-GB", "de-DE"])
    }

    @Test func selectingSupportedAudioLanguageKeepsExactLocale() {
        let prefs = AudioPreferences(
            defaults: makeDefaults(),
            catalog: AudioLanguageCatalog(
                inputLanguageIDs: ["en-US", "en-GB", "de-DE", "fr-FR"],
                voices: [],
                displayLocale: Locale(identifier: "en-US")
            ),
            currentLocale: Locale(identifier: "en-US")
        )

        prefs.selectAudioLanguage("en-GB")

        #expect(prefs.speechInputLanguage == "en-GB")
        #expect(prefs.audioLanguageSelectionID == "en-GB")
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "AudioPreferencesTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func sampleCatalog() -> AudioLanguageCatalog {
        AudioLanguageCatalog(
            inputLanguageIDs: ["en-US", "de-DE", "fr-FR"],
            voices: [
                AudioVoiceDescriptor(identifier: "en-siri", language: "en-US", name: "Siri Voice 1", qualityRank: 1, isSiri: true),
                AudioVoiceDescriptor(identifier: "de-premium", language: "de-DE", name: "Anna", qualityRank: 2, isSiri: false),
                AudioVoiceDescriptor(identifier: "fr-standard", language: "fr-FR", name: "Thomas", qualityRank: 1, isSiri: false),
            ],
            displayLocale: Locale(identifier: "en-US")
        )
    }
}
