import Darwin
import Foundation

enum SampleConversationSeeder {
    static func shouldRun(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("--seed-sample-conversations")
    }

    static func run(arguments: [String] = ProcessInfo.processInfo.arguments) async throws {
        let options = try Options(arguments: Array(arguments.dropFirst()))

        if options.showHelp {
            print("Usage: swift run AirplaneAI --seed-sample-conversations [--replace] [--focus <slug>] [--skip-onboarding]")
            return
        }

        let selected = try selectSamples(focus: options.focusSlug)
        let paths = try storePaths()

        if options.replaceStore {
            try resetStore(at: paths.base)
        }

        try FileManager.default.createDirectory(at: paths.base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.backups, withIntermediateDirectories: true)

        let store = try SwiftDataConversationStore(storeURL: paths.store, backupDirectory: paths.backups)

        if options.replaceStore {
            let existing = try await store.allConversations()
            for conversation in existing {
                try await store.delete(id: conversation.id)
            }
        }

        for sample in selected {
            try await store.save(sample.conversation)
        }
        try await store.saveBackupSnapshot(selected.map(\.conversation))

        if options.completeOnboarding {
            UserDefaults.standard.set(true, forKey: "airplane.hasCompletedOnboarding")
        }

        print("Seeded \(selected.count) conversations into \(paths.store.path)")
    }

    private static func selectSamples(focus: String?) throws -> [SeedSample] {
        guard let focus else { return samples }
        guard let focused = samples.first(where: { $0.slug == focus }) else {
            throw SeedError.unknownSample(focus)
        }
        return [focused] + samples.filter { $0.slug != focus }
    }

    private static func storePaths() throws -> (base: URL, store: URL, backups: URL) {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("AirplaneAI", isDirectory: true)

        return (
            base: base,
            store: base.appendingPathComponent("store.sqlite"),
            backups: base.appendingPathComponent("Backups", isDirectory: true)
        )
    }

    private static func resetStore(at base: URL) throws {
        let fm = FileManager.default
        for name in ["store.sqlite", "store.sqlite-shm", "store.sqlite-wal"] {
            let path = base.appendingPathComponent(name)
            if fm.fileExists(atPath: path.path) {
                try fm.removeItem(at: path)
            }
        }

        let backups = base.appendingPathComponent("Backups", isDirectory: true)
        if fm.fileExists(atPath: backups.path) {
            try fm.removeItem(at: backups)
        }
    }
}

private struct Options {
    let replaceStore: Bool
    let completeOnboarding: Bool
    let focusSlug: String?
    let showHelp: Bool

    init(arguments: [String]) throws {
        var replaceStore = false
        var completeOnboarding = true
        var focusSlug: String?
        var showHelp = false

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--seed-sample-conversations":
                continue
            case "--replace":
                replaceStore = true
            case "--skip-onboarding":
                completeOnboarding = false
            case "--focus":
                guard let value = iterator.next() else {
                    throw SeedError.invalidArguments("--focus requires a slug")
                }
                focusSlug = value
            case "--help", "-h":
                showHelp = true
            default:
                throw SeedError.invalidArguments("unknown argument: \(argument)")
            }
        }

        self.replaceStore = replaceStore
        self.completeOnboarding = completeOnboarding
        self.focusSlug = focusSlug
        self.showHelp = showHelp
    }
}

private enum SeedError: LocalizedError {
    case invalidArguments(String)
    case unknownSample(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        case .unknownSample(let slug):
            return "unknown seed sample: \(slug)"
        }
    }
}

private struct SeedSample {
    let slug: String
    let conversation: Conversation
}

private let samples: [SeedSample] = {
    let baseDate = Date(timeIntervalSince1970: 1_713_139_200)

    func stamp(_ offset: TimeInterval) -> Date {
        baseDate.addingTimeInterval(offset)
    }

    func message(
        role: MessageRole,
        _ content: String,
        minutes offsetMinutes: TimeInterval,
        status: MessageStatus = .complete
    ) -> ChatMessage {
        ChatMessage(
            role: role,
            content: content,
            createdAt: stamp(offsetMinutes * 60),
            status: status
        )
    }

    func conversation(
        slug: String,
        title: String,
        updatedMinutes: TimeInterval,
        messages: [ChatMessage]
    ) -> SeedSample {
        SeedSample(
            slug: slug,
            conversation: Conversation(
                title: title,
                messages: messages,
                createdAt: messages.first?.createdAt ?? stamp(0),
                updatedAt: stamp(updatedMinutes * 60)
            )
        )
    }

    return [
        conversation(
            slug: "hero",
            title: "Write a product launch memo",
            updatedMinutes: 90,
            messages: [
                message(role: .user, "Write a launch memo for Airplane AI. Keep it direct and mention that it runs fully offline on macOS.", minutes: 0),
                message(role: .assistant, """
                Here’s a concise launch memo:

                ## Airplane AI launches today

                Airplane AI is a private, offline AI chat app for macOS. It runs entirely on Apple Silicon hardware with a bundled model, local storage, and no network access at runtime.

                Key points:
                - No accounts, cloud sync, or telemetry
                - Conversations stay on-device
                - Responses stream live with Markdown support
                - Images, documents, and speech are converted to text locally before inference

                Position it as a paid utility for people who want fast AI help without handing their data to a server.
                """, minutes: 2)
            ]
        ),
        conversation(
            slug: "code",
            title: "Fix a brittle shell script",
            updatedMinutes: 80,
            messages: [
                message(role: .user, "Show me a safer bash pattern for copying files only when contents changed.", minutes: 10),
                message(role: .assistant, """
                Use a compare-before-copy branch so warm builds stay cheap:

                ```bash
                sync_file() {
                  local src=\"$1\" dest=\"$2\"
                  mkdir -p \"$(dirname \"$dest\")\"
                  if [[ -f \"$dest\" ]] && cmp -s \"$src\" \"$dest\"; then
                    return 1
                  fi
                  cp -f \"$src\" \"$dest\"
                }
                ```

                That avoids rewriting timestamps and prevents unnecessary codesign work downstream.
                """, minutes: 12)
            ]
        ),
        conversation(
            slug: "travel",
            title: "Vienna weekend ideas",
            updatedMinutes: 70,
            messages: [
                message(role: .user, "Give me a two-day Vienna plan with coffee, museums, and one quiet evening idea.", minutes: 20),
                message(role: .assistant, """
                Day 1:
                - Coffee and breakfast in Neubau
                - Late morning at the Leopold Museum
                - Walk MuseumsQuartier and Burggarten
                - Quiet evening: concert or a long dinner in Josefstadt

                Day 2:
                - Frühstück near Karmelitermarkt
                - Belvedere in the late morning
                - Afternoon Danube Canal walk
                - Quiet evening: bookshop browse and dessert instead of nightlife
                """, minutes: 22)
            ]
        ),
        conversation(
            slug: "settings",
            title: "Context window tradeoffs",
            updatedMinutes: 60,
            messages: [
                message(role: .user, "Explain context window tradeoffs in plain English.", minutes: 30),
                message(role: .assistant, """
                Bigger context windows let the model remember more of the conversation, but they cost memory and can slow generation.

                Practical rule:
                - Small window: faster, safer on 16 GB Macs
                - Large window: better long-session recall on higher-memory machines

                Tune defaults per hardware class, not with one universal slider.
                """, minutes: 31)
            ]
        ),
        conversation(
            slug: "writing",
            title: "Make this sentence more formal",
            updatedMinutes: 55,
            messages: [
                message(role: .user, "Rewrite more formally: \"let me know asap if you can make it\"", minutes: 35),
                message(role: .assistant, """
                A few tiered options:

                - Neutral: "Please confirm your availability at your earliest convenience."
                - Warmer: "Kindly let me know whether you are able to attend."
                - Executive: "Please advise on your attendance when possible."

                All three work for client email; pick based on how close the relationship is.
                """, minutes: 36)
            ]
        ),
        conversation(
            slug: "translate",
            title: "Where is the bathroom — in Japanese",
            updatedMinutes: 50,
            messages: [
                message(role: .user, "Say \"where is the bathroom\" in Japanese.", minutes: 40),
                message(role: .assistant, """
                トイレはどこですか？

                (*Toire wa doko desu ka?*) — polite, works anywhere: restaurants, stations, hotels.

                Slightly softer: お手洗いはどこですか？ (*Otearai wa doko desu ka?*) — a more refined register.
                """, minutes: 41)
            ]
        ),
        conversation(
            slug: "creative",
            title: "Noir story — opening paragraph",
            updatedMinutes: 45,
            messages: [
                message(role: .user, "Opening paragraph of a noir story set in Tokyo.", minutes: 42),
                message(role: .assistant, """
                The rain hit Shibuya like it had a grudge. I stood under the awning of a shuttered pachinko parlor, watching neon bleed across wet asphalt. My client had given me a name, an address in Roppongi, and a photograph. The photograph was the only honest thing in the whole arrangement — which made it the most dangerous.
                """, minutes: 43)
            ]
        ),
        conversation(
            slug: "grammar",
            title: "Fix this sentence",
            updatedMinutes: 40,
            messages: [
                message(role: .user, "Fix: \"their are to many errors in this sentance\"", minutes: 44),
                message(role: .assistant, """
                **There are too many errors in this sentence.**

                Three corrections:
                - *their* → *there* (existence, not possession)
                - *to* → *too* (meaning "excessively")
                - *sentance* → *sentence* (spelling)
                """, minutes: 45)
            ]
        ),
        conversation(
            slug: "quickfact",
            title: "Feet in a mile",
            updatedMinutes: 35,
            messages: [
                message(role: .user, "How many feet in a mile?", minutes: 46),
                message(role: .assistant, "**5,280 feet.**\n\n(Exactly 1,609.344 metres, since 1959.)", minutes: 46.5)
            ]
        ),
        conversation(
            slug: "regex",
            title: "Email regex",
            updatedMinutes: 30,
            messages: [
                message(role: .user, "Regex for a typical email address.", minutes: 48),
                message(role: .assistant, """
                ```
                ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$
                ```

                Good enough for HTML forms and CSV validation. For true RFC-5322 compliance, the only reliable check is to send a confirmation email — the spec allows quoted strings, comments, and IP-literal hosts that no sane regex should try to parse.
                """, minutes: 49)
            ]
        ),
        conversation(
            slug: "debugging",
            title: "SwiftUI view not updating",
            updatedMinutes: 25,
            messages: [
                message(role: .user, "Why would a SwiftUI view not update when my @Observable model changes?", minutes: 50),
                message(role: .assistant, """
                Most common causes, in order:

                1. You're mutating the model off the `MainActor`. `@Observable` tracking assumes main-thread writes.
                2. The view captured a *copy* instead of the reference. Pass the model via `@Bindable` or `@Environment`.
                3. The property you read isn't actually the one that changes — check you're observing the same path.
                4. You used `let` on a value type that you then replace; SwiftUI can't re-render if the property never mutates.

                Quickest diagnostic: print the model's identity in `body` — if it changes across updates but the view doesn't, you have a diffing issue.
                """, minutes: 51)
            ]
        )
    ]
}()
