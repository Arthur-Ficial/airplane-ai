import Foundation

/// Headless executor for `airplaneai` CLI invocations. Reuses the same engine
/// + store instances as the GUI when wired through `AppWiring`, but runs
/// entirely without any SwiftUI or AppKit.
public struct CLIRunner: Sendable {
    public let engine: InferenceEngine
    public let store: ConversationStore
    public let systemPrompt: String

    public init(engine: InferenceEngine, store: ConversationStore, systemPrompt: String) {
        self.engine = engine
        self.store = store
        self.systemPrompt = systemPrompt
    }

    /// Returns a POSIX-style exit code (0 success, 2 user error, 3 not found, 1 other).
    @discardableResult
    public func run(arguments: [String], output: CLIOutput = StandardCLIOutput()) async -> Int32 {
        let parsed: CLIArguments
        do {
            parsed = try CLIArguments.parse(arguments)
        } catch let error as CLIArgumentError {
            output.writeError(describe(error) + "\n")
            output.writeError(Self.usage)
            return 2
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 2
        }

        switch parsed.mode {
        case .help:
            output.write(Self.usage)
            return 0
        case .version:
            output.write("airplaneai v\(Self.version)\n")
            return 0
        case .list:
            return await runList(output: output)
        case .show:
            return await runShow(name: parsed.name!, output: output)
        case .delete:
            return await runDelete(name: parsed.name!, output: output)
        case .single:
            return await runSingle(args: parsed, output: output)
        case .named:
            return await runNamed(args: parsed, output: output)
        }
    }

    // MARK: - Commands

    private func runList(output: CLIOutput) async -> Int32 {
        do {
            let all = try await store.allConversations()
            if all.isEmpty {
                output.write("(no conversations)\n")
            } else {
                for c in all {
                    output.write("\(c.title)\t(\(c.messages.count) msgs)\n")
                }
            }
            return 0
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 1
        }
    }

    private func runShow(name: String, output: CLIOutput) async -> Int32 {
        do {
            guard let convo = try await findByName(name) else {
                output.writeError("error: no chat named '\(name)'\n")
                return 3
            }
            for m in convo.messages {
                output.write("### \(m.role.rawValue)\n")
                output.write(m.content + "\n\n")
            }
            return 0
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 1
        }
    }

    private func runDelete(name: String, output: CLIOutput) async -> Int32 {
        do {
            guard let convo = try await findByName(name) else {
                output.writeError("error: no chat named '\(name)'\n")
                return 3
            }
            try await store.delete(id: convo.id)
            output.write("deleted: \(name)\n")
            return 0
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 1
        }
    }

    private func runSingle(args: CLIArguments, output: CLIOutput) async -> Int32 {
        guard let prompt = args.prompt else { return 2 }
        let userMessage = ChatMessage(role: .user, content: prompt, createdAt: Date(), status: .complete)
        let reply = await generate(
            messages: [userMessage],
            args: args,
            output: output
        )
        return reply == nil ? 1 : 0
    }

    private func runNamed(args: CLIArguments, output: CLIOutput) async -> Int32 {
        guard let prompt = args.prompt, let name = args.name else { return 2 }

        var convo: Conversation
        do {
            if let existing = try await findByName(name) {
                if args.replacing {
                    convo = Conversation(title: name, messages: [])
                } else {
                    convo = existing
                }
            } else if args.continuing {
                output.writeError("error: no chat named '\(name)' — run without --continue to create\n")
                return 3
            } else {
                convo = Conversation(title: name, messages: [])
            }
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 1
        }

        let userMessage = ChatMessage(role: .user, content: prompt, createdAt: Date(), status: .complete)
        convo.messages.append(userMessage)

        guard let reply = await generate(messages: convo.messages, args: args, output: output) else {
            return 1
        }

        let assistant = ChatMessage(role: .assistant, content: reply, createdAt: Date(), status: .complete)
        convo.messages.append(assistant)
        convo.updatedAt = Date()

        do {
            try await store.save(convo)
            return 0
        } catch {
            output.writeError("error: \(error.localizedDescription)\n")
            return 1
        }
    }

    // MARK: - Generation

    private func generate(
        messages: [ChatMessage],
        args: CLIArguments,
        output: CLIOutput
    ) async -> String? {
        let system = args.systemOverride ?? systemPrompt
        let fullMessages: [ChatMessage]
        if messages.first?.role == .system {
            fullMessages = messages
        } else {
            let sys = ChatMessage(role: .system, content: system, createdAt: Date(), status: .complete)
            fullMessages = [sys] + messages
        }

        let params = GenerationParameters(
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            maxTokens: args.maxTokens ?? 1024,
            repeatPenalty: 1.1,
            seed: args.seed.map { Int32(truncatingIfNeeded: $0) } ?? -1
        )

        var accumulated = ""
        do {
            for try await event in engine.generate(messages: fullMessages, parameters: params) {
                switch event {
                case .token(let chunk):
                    accumulated += chunk.text
                    if !args.quiet && !args.json { output.write(chunk.text) }
                case .finished:
                    break
                }
            }
            if args.json {
                output.write(jsonResponse(reply: accumulated, args: args) + "\n")
            } else {
                if args.quiet { output.write(accumulated) }
                output.write("\n")
            }
            return accumulated
        } catch {
            output.writeError("\nerror: \(error.localizedDescription)\n")
            return nil
        }
    }

    // MARK: - Helpers

    private func findByName(_ name: String) async throws -> Conversation? {
        let all = try await store.allConversations()
        return all.first { $0.title == name }
    }

    private func describe(_ error: CLIArgumentError) -> String {
        switch error {
        case .missingPrompt: return "error: missing prompt"
        case .missingValue(let flag): return "error: \(flag) requires a value"
        case .unknownFlag(let f): return "error: unknown flag \(f)"
        case .incompatibleFlags(let msg): return "error: \(msg)"
        case .invalidInteger(let flag, let value): return "error: \(flag) expects integer, got '\(value)'"
        }
    }

    private func jsonResponse(reply: String, args: CLIArguments) -> String {
        struct Payload: Encodable {
            let mode: String
            let name: String?
            let prompt: String?
            let reply: String
        }

        let payload = Payload(
            mode: String(describing: args.mode),
            name: args.name,
            prompt: args.prompt,
            reply: reply
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"reply\":\"\(reply.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        }
        return string
    }

    public static let version = "0.3.0"

    public static let usage = """
    airplaneai — private offline AI chat from the command line

    USAGE:
      airplaneai -p <prompt>                    single-shot (not persisted)
      airplaneai -p <prompt> -n <name>          named chat (persisted)
      airplaneai -p <prompt> -n <name> --continue   continue existing chat
      airplaneai -p <prompt> -n <name> --new        replace named chat contents
      airplaneai --list                         list saved chats
      airplaneai --show -n <name>               print chat transcript
      airplaneai --delete -n <name>             delete a chat

    OPTIONS:
      -p, --prompt <text>       The prompt
      -n, --name <slug>         Named persistent chat
      --continue                Require the named chat to exist
      --new                     Replace the named chat if it already exists
      -s, --system <text>       Override system prompt
      --max-tokens <n>          Cap output tokens
      --seed <n>                Reproducible sampling
      -q, --quiet               Suppress streaming, print final reply
      --json                    Output as JSON
      -h, --help                Show this help
      -v, --version             Print version

    """
}
