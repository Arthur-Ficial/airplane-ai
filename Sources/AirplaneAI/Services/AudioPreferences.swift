import AVFoundation
import Foundation
import Observation
import Speech

public struct AudioVoiceDescriptor: Equatable, Sendable {
    public let identifier: String
    public let language: String
    public let name: String
    public let qualityRank: Int
    public let isSiri: Bool

    public init(
        identifier: String,
        language: String,
        name: String,
        qualityRank: Int,
        isSiri: Bool
    ) {
        self.identifier = identifier
        self.language = language
        self.name = name
        self.qualityRank = qualityRank
        self.isSiri = isSiri
    }
}

public struct AudioLanguageOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let subtitle: String
    public let supportsInput: Bool
    public let supportsOutput: Bool
    public let hasSiriVoice: Bool

    public init(
        id: String,
        displayName: String,
        subtitle: String,
        supportsInput: Bool,
        supportsOutput: Bool,
        hasSiriVoice: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.subtitle = subtitle
        self.supportsInput = supportsInput
        self.supportsOutput = supportsOutput
        self.hasSiriVoice = hasSiriVoice
    }
}

public struct AudioLanguageCatalog: Sendable {
    public let audioLanguages: [AudioLanguageOption]
    public let inputLanguages: [AudioLanguageOption]
    public let outputLanguages: [AudioLanguageOption]
    public let voices: [AudioVoiceDescriptor]

    public init(
        inputLanguageIDs: [String],
        voices: [AudioVoiceDescriptor],
        displayLocale: Locale = .current
    ) {
        let normalizedInputs = Set(inputLanguageIDs.filter { !$0.isEmpty })
        let voiceGroups = Dictionary(grouping: voices) { $0.language }
        let allLanguageIDs = Set(normalizedInputs).union(voiceGroups.keys)

        let options = allLanguageIDs.map { identifier in
            AudioLanguageOption(
                id: identifier,
                displayName: Self.displayName(for: identifier, locale: displayLocale),
                subtitle: Self.subtitle(for: identifier),
                supportsInput: normalizedInputs.contains(identifier),
                supportsOutput: voiceGroups[identifier] != nil,
                hasSiriVoice: voiceGroups[identifier]?.contains(where: \.isSiri) == true
            )
        }
        .sorted(by: Self.sortOptions)

        self.audioLanguages = options
        self.inputLanguages = options.filter { $0.supportsInput }
        self.outputLanguages = options.filter { $0.supportsOutput }
        self.voices = voices.sorted(by: Self.sortVoices)
    }

    public static func system(displayLocale: Locale = .current) -> AudioLanguageCatalog {
        let voices = AVSpeechSynthesisVoice.speechVoices().map { voice in
            AudioVoiceDescriptor(
                identifier: voice.identifier,
                language: voice.language,
                name: voice.name,
                qualityRank: Int(voice.quality.rawValue),
                isSiri: isSiriVoice(name: voice.name, identifier: voice.identifier)
            )
        }
        return AudioLanguageCatalog(
            inputLanguageIDs: SFSpeechRecognizer.supportedLocales().map(\.identifier),
            voices: voices,
            displayLocale: displayLocale
        )
    }

    public func preferredInputLanguage(currentLocale: Locale = .current) -> String? {
        pickBestLanguage(
            preferredIdentifier: currentLocale.identifier,
            from: inputLanguages.map(\.id)
        )
    }

    public func preferredOutputLanguage(currentLocale: Locale = .current) -> String? {
        let preferred = pickBestLanguage(
            preferredIdentifier: currentLocale.identifier,
            from: outputLanguages.map(\.id)
        )
        if let preferred {
            return preferred
        }
        return outputLanguages.first(where: \.hasSiriVoice)?.id ?? outputLanguages.first?.id
    }

    public func normalizedInputLanguage(_ identifier: String?) -> String? {
        normalize(identifier, available: inputLanguages.map(\.id))
    }

    public func normalizedOutputLanguage(_ identifier: String?) -> String? {
        normalize(identifier, available: outputLanguages.map(\.id))
    }

    public func resolveAudioSelection(_ identifier: String) -> (input: String?, output: String?) {
        (
            input: pickBestLanguage(preferredIdentifier: identifier, from: inputLanguages.map(\.id)),
            output: pickBestLanguage(preferredIdentifier: identifier, from: outputLanguages.map(\.id))
        )
    }

    public static func preferredVoiceIdentifier(
        for languageCode: String,
        availableVoices: [AudioVoiceDescriptor]
    ) -> String? {
        let exact = availableVoices
            .filter { $0.language == languageCode }
            .sorted(by: sortVoices)
        if let voice = exact.first {
            return voice.identifier
        }

        let requestedBase = baseLanguageCode(for: languageCode)
        let baseMatches = availableVoices
            .filter { baseLanguageCode(for: $0.language) == requestedBase }
            .sorted(by: sortVoices)
        return baseMatches.first?.identifier
    }

    private func normalize(_ identifier: String?, available: [String]) -> String? {
        if let identifier,
           let match = pickBestLanguage(preferredIdentifier: identifier, from: available) {
            return match
        }
        return nil
    }

    private func pickBestLanguage(preferredIdentifier: String, from available: [String]) -> String? {
        prioritizedLanguages(preferredIdentifier: preferredIdentifier, from: available).first
    }

    private func prioritizedLanguages(preferredIdentifier: String, from available: [String]) -> [String] {
        guard !available.isEmpty else { return [] }
        var candidates: [String] = []
        if available.contains(preferredIdentifier) {
            candidates.append(preferredIdentifier)
        }

        let preferredBase = Self.baseLanguageCode(for: preferredIdentifier)
        candidates.append(contentsOf: available.filter {
            $0 != preferredIdentifier && Self.baseLanguageCode(for: $0) == preferredBase
        })

        candidates.append(contentsOf: available.filter {
            !candidates.contains($0) && Self.baseLanguageCode(for: $0) == "en"
        })

        candidates.append(contentsOf: available.filter { !candidates.contains($0) })
        return candidates
    }

    private static func displayName(for identifier: String, locale: Locale) -> String {
        locale.localizedString(forIdentifier: identifier)
            ?? locale.localizedString(forLanguageCode: baseLanguageCode(for: identifier))
            ?? identifier
    }

    private static func subtitle(for identifier: String) -> String {
        let locale = Locale(identifier: identifier)
        let region = locale.region?.identifier
        if let region, !region.isEmpty {
            return "\(identifier) • \(region)"
        }
        return identifier
    }

    private static func sortOptions(lhs: AudioLanguageOption, rhs: AudioLanguageOption) -> Bool {
        let lhsRank = sortRank(for: lhs.id)
        let rhsRank = sortRank(for: rhs.id)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        if lhs.displayName != rhs.displayName {
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private static func sortVoices(lhs: AudioVoiceDescriptor, rhs: AudioVoiceDescriptor) -> Bool {
        if lhs.isSiri != rhs.isSiri {
            return lhs.isSiri
        }
        if lhs.qualityRank != rhs.qualityRank {
            return lhs.qualityRank > rhs.qualityRank
        }
        if lhs.language != rhs.language {
            return lhs.language < rhs.language
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func isSiriVoice(name: String, identifier: String) -> Bool {
        let haystack = "\(name) \(identifier)".lowercased()
        return haystack.contains("siri")
    }

    private static func sortRank(for identifier: String) -> Int {
        if let exact = featuredLanguageOrder.firstIndex(of: identifier) {
            return exact
        }
        if isEuropeanLanguage(identifier) {
            return 100
        }
        return 200
    }

    private static func isEuropeanLanguage(_ identifier: String) -> Bool {
        let locale = Locale(identifier: identifier)
        let base = baseLanguageCode(for: identifier)
        if europeanLanguageCodes.contains(base) {
            return true
        }
        if let region = locale.region?.identifier {
            return europeanRegionCodes.contains(region)
        }
        return false
    }

    private static let featuredLanguageOrder = [
        "en-US",
        "en-001",
        "en-GB",
        "de-DE",
    ]

    private static let europeanLanguageCodes: Set<String> = [
        "bg", "ca", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr", "ga",
        "hr", "hu", "is", "it", "lt", "lv", "mt", "nl", "no", "pl", "pt", "ro",
        "sk", "sl", "sq", "sr", "sv", "uk"
    ]

    private static let europeanRegionCodes: Set<String> = [
        "AD", "AL", "AT", "AX", "BA", "BE", "BG", "BY", "CH", "CY", "CZ", "DE",
        "DK", "EE", "ES", "FI", "FO", "FR", "GB", "GG", "GI", "GR", "HR", "HU",
        "IE", "IM", "IS", "IT", "JE", "LI", "LT", "LU", "LV", "MC", "MD", "ME",
        "MK", "MT", "NL", "NO", "PL", "PT", "RO", "RS", "SE", "SI", "SK", "SM",
        "UA", "VA"
    ]

    private static func baseLanguageCode(for identifier: String) -> String {
        Locale(identifier: identifier).language.languageCode?.identifier
            ?? identifier.split(separator: "-").first.map(String.init)
            ?? identifier
    }
}

@MainActor
@Observable
public final class AudioPreferences {
    public var speechInputLanguage: String {
        didSet {
            defaults.set(speechInputLanguage, forKey: Self.inputLanguageKey)
        }
    }

    public var speechOutputLanguage: String {
        didSet {
            defaults.set(speechOutputLanguage, forKey: Self.outputLanguageKey)
        }
    }

    public var speechOutputEnabled: Bool {
        didSet {
            defaults.set(speechOutputEnabled, forKey: Self.outputEnabledKey)
        }
    }

    public var audioLanguageOptions: [AudioLanguageOption] {
        catalog.audioLanguages
    }

    public var audioLanguageSelectionID: String {
        if speechInputLanguage == speechOutputLanguage {
            return speechInputLanguage
        }
        let inputBase = Self.baseLanguageCode(for: speechInputLanguage)
        let outputBase = Self.baseLanguageCode(for: speechOutputLanguage)
        if inputBase == outputBase {
            return speechInputLanguage
        }
        return speechOutputLanguage
    }

    public let catalog: AudioLanguageCatalog

    private let defaults: UserDefaults

    static let inputLanguageKey = "airplane.audio.inputLanguage"
    static let outputLanguageKey = "airplane.audio.outputLanguage"
    static let outputEnabledKey = "airplane.audio.outputEnabled"

    public init(
        defaults: UserDefaults = .standard,
        catalog: AudioLanguageCatalog = .system(),
        currentLocale: Locale = .current
    ) {
        self.defaults = defaults
        self.catalog = catalog

        let storedInput = defaults.string(forKey: Self.inputLanguageKey)
        let storedOutput = defaults.string(forKey: Self.outputLanguageKey)
        self.speechInputLanguage = catalog.normalizedInputLanguage(storedInput)
            ?? catalog.preferredInputLanguage(currentLocale: currentLocale)
            ?? "en-US"
        self.speechOutputLanguage = catalog.normalizedOutputLanguage(storedOutput)
            ?? catalog.preferredOutputLanguage(currentLocale: currentLocale)
            ?? "en-US"
        self.speechOutputEnabled = defaults.object(forKey: Self.outputEnabledKey) as? Bool ?? false
    }

    private func normalizedInput(_ identifier: String) -> String {
        catalog.normalizedInputLanguage(identifier)
            ?? catalog.preferredInputLanguage()
            ?? speechInputLanguage
    }

    private func normalizedOutput(_ identifier: String) -> String {
        catalog.normalizedOutputLanguage(identifier)
            ?? catalog.preferredOutputLanguage()
            ?? speechOutputLanguage
    }

    public func selectSpeechInputLanguage(_ identifier: String) {
        speechInputLanguage = normalizedInput(identifier)
    }

    public func selectSpeechOutputLanguage(_ identifier: String) {
        speechOutputLanguage = normalizedOutput(identifier)
    }

    public func selectAudioLanguage(_ identifier: String) {
        let resolved = catalog.resolveAudioSelection(identifier)
        if let input = resolved.input {
            speechInputLanguage = input
        }
        if let output = resolved.output {
            speechOutputLanguage = output
        }
    }

    private static func baseLanguageCode(for identifier: String) -> String {
        Locale(identifier: identifier).language.languageCode?.identifier
            ?? identifier.split(separator: "-").first.map(String.init)
            ?? identifier
    }
}
