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
    // Base anchored recently so the UI shows natural "minutes/hours ago"
    // timestamps rather than "2 years ago" for seeded demo content.
    let baseDate = Date(timeIntervalSinceNow: -6 * 60 * 60)

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
            title: "Product launch memo",
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
                """, minutes: 2),
                message(role: .user, "Shorter — just the three strongest sentences for a press release lede.", minutes: 3),
                message(role: .assistant, """
                Airplane AI is the first macOS chat app that physically cannot phone home. Your conversations stay on your Mac — enforced by kernel-level sandboxing, not a privacy policy. One purchase, yours forever.
                """, minutes: 4)
            ]
        ),
        conversation(
            slug: "code",
            title: "Safer bash file copy",
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
                """, minutes: 12),
                message(role: .user, "How do I handle broken symlinks in the source path?", minutes: 14),
                message(role: .assistant, """
                Guard the copy with `-L` resolution and a readability check first:

                ```bash
                sync_file() {
                  local src=\"$1\" dest=\"$2\"
                  if [[ ! -e \"$src\" ]]; then
                    printf 'skip: %s (missing or broken symlink)\\n' \"$src\" >&2
                    return 2
                  fi
                  mkdir -p \"$(dirname \"$dest\")\"
                  if [[ -f \"$dest\" ]] && cmp -s \"$src\" \"$dest\"; then
                    return 1
                  fi
                  cp -fL \"$src\" \"$dest\"
                }
                ```

                `-e` returns false for broken symlinks; `cp -fL` follows them when the target exists. Exit codes distinguish copy vs skip vs error so callers can count without re-running `stat`.
                """, minutes: 16)
            ]
        ),
        conversation(
            slug: "travel",
            title: "Vienna weekend, coffee focus",
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
                """, minutes: 22),
                message(role: .user, "Can you swap the Leopold for something smaller and less touristy?", minutes: 24),
                message(role: .assistant, """
                Good call. Two options that hit the same \"classic Vienna art\" beat without the crowds:

                - **Dorotheum** (auction house + gallery) — browsable, quirky, free. Ten minutes from Neubau on foot.
                - **Wien Museum MUSA** — small, curated, often has a single sharp theme running.

                Both are quieter midweek mornings. Keep the MuseumsQuartier walk afterwards; it's the best part anyway and doesn't require a ticket.
                """, minutes: 26)
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
                """, minutes: 31),
                message(role: .user, "What actually happens when I hit the limit mid-conversation?", minutes: 32),
                message(role: .assistant, """
                The app trims the *oldest* messages to make room for the newest one plus the system prompt. Nothing gets silently cut off — you'll see a small \"earlier messages hidden\" divider where the trim happened.

                The system prompt and your current message are never trimmed. If a single message alone is too big to fit, the app refuses it with a clear error rather than quietly truncating it.
                """, minutes: 33)
            ]
        ),
        conversation(
            slug: "writing",
            title: "Make this more formal",
            updatedMinutes: 55,
            messages: [
                message(role: .user, "Rewrite more formally: \"let me know asap if you can make it\"", minutes: 35),
                message(role: .assistant, """
                A few tiered options:

                - Neutral: \"Please confirm your availability at your earliest convenience.\"
                - Warmer: \"Kindly let me know whether you are able to attend.\"
                - Executive: \"Please advise on your attendance when possible.\"

                All three work for client email; pick based on how close the relationship is.
                """, minutes: 36),
                message(role: .user, "Now make the warmest one sound a little more senior.", minutes: 37),
                message(role: .assistant, """
                \"I'd appreciate a note on whether you're able to join us — no rush, but it helps with planning.\"

                That keeps the warmth but signals seniority two ways: the apology-free \"no rush\" (confident, not anxious) and the collective \"us\" (implies you're speaking for a team rather than asking a personal favour).
                """, minutes: 38)
            ]
        ),
        conversation(
            slug: "translate",
            title: "Bathroom in Japanese, then Spanish",
            updatedMinutes: 50,
            messages: [
                message(role: .user, "Say \"where is the bathroom\" in Japanese.", minutes: 40),
                message(role: .assistant, """
                **トイレはどこですか？**

                (*Toire wa doko desu ka?*) — polite, works anywhere: restaurants, stations, hotels.

                Slightly softer: お手洗いはどこですか？ (*Otearai wa doko desu ka?*) — a more refined register, good for nicer restaurants or older hosts.
                """, minutes: 41),
                message(role: .user, "And in Spanish?", minutes: 42),
                message(role: .assistant, """
                **¿Dónde está el baño?**

                Universal across Spain and Latin America. In Spain you'll also hear *el aseo* (more formal, common on signs); in Mexico *el sanitario* is the polite version on menus and public notices.
                """, minutes: 43)
            ]
        ),
        conversation(
            slug: "creative",
            title: "Noir opening set in Tokyo",
            updatedMinutes: 45,
            messages: [
                message(role: .user, "Opening paragraph of a noir story set in Tokyo.", minutes: 42),
                message(role: .assistant, """
                The rain hit Shibuya like it had a grudge. I stood under the awning of a shuttered pachinko parlor, watching neon bleed across wet asphalt. My client had given me a name, an address in Roppongi, and a photograph. The photograph was the only honest thing in the whole arrangement — which made it the most dangerous.
                """, minutes: 43),
                message(role: .user, "Heavier rain, and hint at what's in the photograph without saying.", minutes: 44),
                message(role: .assistant, """
                The rain came down hard enough to drown the neon. Shibuya looked like somebody had poured gasoline into a gutter and lit it — all red and blue running together, nothing holding its shape. I stood under the awning of a shuttered pachinko parlor with a photograph in my inside pocket, the corner already soft from the damp. I hadn't looked at it in an hour. I didn't need to. Some images stay where you put them, and this one had teeth.
                """, minutes: 46)
            ]
        ),
        conversation(
            slug: "grammar",
            title: "Grammar fix, and the why",
            updatedMinutes: 40,
            messages: [
                message(role: .user, "Fix: \"their are to many errors in this sentance\"", minutes: 44),
                message(role: .assistant, """
                **There are too many errors in this sentence.**

                Three corrections:
                - *their* → *there* (existence, not possession)
                - *to* → *too* (meaning \"excessively\")
                - *sentance* → *sentence* (spelling)
                """, minutes: 45),
                message(role: .user, "Why \"too\" and not \"to\" here?", minutes: 46),
                message(role: .assistant, """
                Three different words that sound identical:

                - **to** — preposition or infinitive marker. \"Go **to** the store.\" \"I want **to** leave.\"
                - **too** — means \"also\" or \"excessively.\" \"Me **too**.\" \"**Too** many errors.\"
                - **two** — the number 2.

                Here you want the \"excessively\" sense (many beyond what's acceptable), so **too**. A quick test: if you can swap in \"excessively\" or \"also\" and the sentence still works, it's *too*.
                """, minutes: 47)
            ]
        ),
        conversation(
            slug: "quickfact",
            title: "Miles, feet, metres",
            updatedMinutes: 35,
            messages: [
                message(role: .user, "How many feet in a mile?", minutes: 46),
                message(role: .assistant, "**5,280 feet.**\n\n(Exactly 1,609.344 metres, since 1959 — when the English-speaking world finally agreed on a single definition.)", minutes: 46.5),
                message(role: .user, "And how many kilometres in a marathon?", minutes: 47),
                message(role: .assistant, """
                **42.195 km** — or 26 miles 385 yards.

                The odd 385 yards was added at the 1908 London Olympics so the race could finish in front of the royal box at White City Stadium. The rest of the sporting world never undid it.
                """, minutes: 48)
            ]
        ),
        conversation(
            slug: "regex",
            title: "Email regex (and its limits)",
            updatedMinutes: 30,
            messages: [
                message(role: .user, "Regex for a typical email address.", minutes: 48),
                message(role: .assistant, """
                ```
                ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$
                ```

                Good enough for HTML forms and CSV validation. For true RFC-5322 compliance, the only reliable check is to send a confirmation email — the spec allows quoted strings, comments, and IP-literal hosts that no sane regex should try to parse.
                """, minutes: 49),
                message(role: .user, "Give me an anchored Swift version that handles unicode domains.", minutes: 50),
                message(role: .assistant, """
                Swift 5.7+ with the Regex builder handles this cleanly:

                ```swift
                import Foundation

                func isProbablyEmail(_ input: String) -> Bool {
                    guard let at = input.firstIndex(of: \"@\") else { return false }
                    let local = input[..<at]
                    let host  = input[input.index(after: at)...]
                    return !local.isEmpty
                        && host.contains(\".\")
                        && local.allSatisfy { $0.isLetter || $0.isNumber || \".-_+%\".contains($0) }
                        && host.allSatisfy { $0.isLetter || $0.isNumber || \".-\".contains($0) }
                }
                ```

                Using `Character.isLetter` instead of `[A-Za-z]` lets *café@münchen.de* pass, which the ASCII-only regex would reject. Still not RFC-compliant; still only a sanity check.
                """, minutes: 52)
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
                """, minutes: 51),
                message(role: .user, "How do I check I'm actually writing on the MainActor?", minutes: 53),
                message(role: .assistant, """
                Three levels of strictness:

                ```swift
                // 1. Runtime assertion — crashes in debug if wrong
                MainActor.assertIsolated()

                // 2. Isolation check — true/false, no crash
                if MainActor.shared.isExecuting { ... }

                // 3. Compile-time guarantee — mark the method @MainActor
                @MainActor func update(_ value: Int) {
                    self.count = value   // compiler refuses off-main callers
                }
                ```

                Prefer option 3 whenever you can — the compiler catches the bug before you run the app. Use the runtime assert only at the edge where you're receiving a callback from a non-isolated API (Combine, network callbacks, etc.).
                """, minutes: 55)
            ]
        )
    ]
}()
