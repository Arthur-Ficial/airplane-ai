import Testing
import Foundation
@testable import AirplaneAI

@Suite("CLIRunner", .serialized)
struct CLIRunnerTests {
    @Test("single-shot prints engine reply to stdout and exits 0")
    func singleShot() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["fo", "ur"]
        let store = MockConversationStore()
        let runner = CLIRunner(engine: engine, store: store, systemPrompt: "sys")
        let output = CapturingCLIOutput()

        let code = await runner.run(arguments: ["-p", "What is 2+2?", "-q"], output: output)

        #expect(code == 0)
        #expect(output.stdout.contains("four"))
    }

    @Test("named new chat persists user + assistant turn")
    func namedNewChat() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["closures ", "capture ", "state"]
        let store = MockConversationStore()
        let runner = CLIRunner(engine: engine, store: store, systemPrompt: "sys")
        let output = CapturingCLIOutput()

        let code = await runner.run(
            arguments: ["-p", "Explain closures.", "-n", "swift-learning", "-q"],
            output: output
        )

        #expect(code == 0)
        let all = try await store.allConversations()
        let saved = all.first { $0.title == "swift-learning" }
        #expect(saved != nil)
        #expect(saved?.messages.count == 2)
        #expect(saved?.messages.first?.role == .user)
        #expect(saved?.messages.last?.content.contains("capture") == true)
    }

    @Test("--new replaces existing named chat contents")
    func replacingChat() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["fresh ", "reply"]
        let store = MockConversationStore()
        try await store.save(Conversation(
            title: "swift-learning",
            messages: [
                ChatMessage(role: .user, content: "old", createdAt: Date(), status: .complete),
                ChatMessage(role: .assistant, content: "stale", createdAt: Date(), status: .complete),
            ]
        ))
        let runner = CLIRunner(engine: engine, store: store, systemPrompt: "sys")
        let output = CapturingCLIOutput()

        let code = await runner.run(
            arguments: ["-p", "Explain closures.", "-n", "swift-learning", "--new", "-q"],
            output: output
        )

        #expect(code == 0)
        let saved = try await store.allConversations().first { $0.title == "swift-learning" }
        #expect(saved?.messages.count == 2)
        #expect(saved?.messages.first?.content == "Explain closures.")
        #expect(saved?.messages.last?.content == "fresh reply")
    }

    @Test("--continue on existing chat appends rather than replacing")
    func continueChat() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["Here's ", "an ", "example."]
        let store = MockConversationStore()
        let seeded = Conversation(
            title: "swift-learning",
            messages: [
                ChatMessage(role: .user, content: "Explain closures.", createdAt: Date(), status: .complete),
                ChatMessage(role: .assistant, content: "A closure captures state.", createdAt: Date(), status: .complete),
            ]
        )
        try await store.save(seeded)

        let runner = CLIRunner(engine: engine, store: store, systemPrompt: "sys")
        let output = CapturingCLIOutput()

        let code = await runner.run(
            arguments: ["-p", "Give me an example.", "-n", "swift-learning", "--continue", "-q"],
            output: output
        )

        #expect(code == 0)
        let all = try await store.allConversations()
        let saved = all.first { $0.title == "swift-learning" }
        #expect(saved?.messages.count == 4)
    }

    @Test("--continue on missing chat exits 3")
    func continueMissing() async throws {
        let runner = CLIRunner(
            engine: MockInferenceEngine(),
            store: MockConversationStore(),
            systemPrompt: "sys"
        )
        let output = CapturingCLIOutput()

        let code = await runner.run(
            arguments: ["-p", "follow up", "-n", "never-existed", "--continue", "-q"],
            output: output
        )

        #expect(code == 3)
    }

    @Test("--list prints all conversation names")
    func listConversations() async throws {
        let store = MockConversationStore()
        try await store.save(Conversation(title: "alpha", messages: []))
        try await store.save(Conversation(title: "beta", messages: []))

        let runner = CLIRunner(
            engine: MockInferenceEngine(),
            store: store,
            systemPrompt: "sys"
        )
        let output = CapturingCLIOutput()

        let code = await runner.run(arguments: ["--list"], output: output)

        #expect(code == 0)
        #expect(output.stdout.contains("alpha"))
        #expect(output.stdout.contains("beta"))
    }

    @Test("invalid flag exits 2")
    func invalidFlagExits2() async throws {
        let runner = CLIRunner(
            engine: MockInferenceEngine(),
            store: MockConversationStore(),
            systemPrompt: "sys"
        )
        let output = CapturingCLIOutput()

        let code = await runner.run(arguments: ["--nope"], output: output)

        #expect(code == 2)
    }

    @Test("--json emits JSON payload")
    func jsonOutput() async throws {
        let engine = MockInferenceEngine()
        engine.scriptedTokens = ["fo", "ur"]
        let runner = CLIRunner(
            engine: engine,
            store: MockConversationStore(),
            systemPrompt: "sys"
        )
        let output = CapturingCLIOutput()

        let code = await runner.run(arguments: ["-p", "What is 2+2?", "--json"], output: output)

        #expect(code == 0)
        #expect(output.stdout.contains("\"reply\""))
        #expect(output.stdout.contains("four"))
    }
}

final class CapturingCLIOutput: CLIOutput, @unchecked Sendable {
    private let lock = NSLock()
    private var _stdout = ""
    private var _stderr = ""

    var stdout: String { lock.withLock { _stdout } }
    var stderr: String { lock.withLock { _stderr } }

    func write(_ text: String) {
        lock.withLock { _stdout += text }
    }

    func writeError(_ text: String) {
        lock.withLock { _stderr += text }
    }
}
