import Foundation
import Testing
@testable import AirplaneAI

// 50-prompt battery run against the real model. Produces a human-readable
// transcript at build/eval-50.md for UX review (markdown rendering, code
// blocks, lists, tables, separators, unicode).
@Suite("50-question battery", .disabled(if: ProcessInfo.processInfo.environment["AIRPLANE_RUN_EVAL"] == nil))
struct FiftyQuestionBattery {

    static let prompts: [String] = [
        // Knowledge / facts
        "What is the capital of Austria?",
        "Name three well-known Austrian composers.",
        "Who wrote 'The Castle'?",
        "What is the atomic number of oxygen?",
        "Explain photosynthesis in one sentence.",
        // Reasoning / math
        "If I have 17 apples and give 5 away, then buy 3 dozen more, how many do I have?",
        "What is 234 × 47?",
        "Is 97 a prime number? Why?",
        "A bat and a ball cost $1.10 total. The bat costs $1 more than the ball. How much is the ball?",
        "What's the next number: 2, 6, 12, 20, 30, ...?",
        // Code
        "Write a Swift function that reverses a string.",
        "Implement binary search in Python with a docstring.",
        "Show a Rust hello world with a match expression.",
        "Write a SQL query that selects the top 5 users by order count.",
        "Explain what this JavaScript does: `const x = (a, b) => a ?? b;`",
        // Lists / formatting
        "List five macOS keyboard shortcuts with a brief description each.",
        "Give me a checklist for preparing a pull request.",
        "Enumerate the five stages of grief.",
        "List the planets in our solar system in order.",
        "What are the four Noble Truths of Buddhism?",
        // Tables
        "Make a 4-row comparison table: Swift vs Rust on memory model, safety, concurrency, ecosystem.",
        "Produce a table of HTTP status codes 200, 301, 404, 500 with meanings.",
        // Writing
        "Write a haiku about Vienna coffee houses.",
        "Write a 30-word product description for a private on-device AI app.",
        "Translate 'Good morning' to German, French, and Japanese.",
        "Summarize 'The Little Prince' in three sentences.",
        // Unicode / emoji
        "Output five animal emojis and label each.",
        "Give me a sentence in English, German, Greek, and Japanese.",
        // Code blocks
        "Show a minimal SwiftUI view with a button.",
        "Write a Makefile with `build`, `test`, and `clean` targets.",
        "Produce a bash one-liner that counts unique words in a file.",
        // Reasoning / chains
        "If today is Friday, what day will it be in 100 days?",
        "I have three boxes. One has 5 balls, one has 3, one has 8. The middle box has the median count — which box is it?",
        // Edge / tricky
        "Repeat the word 'airplane' 7 times, comma-separated.",
        "Write a palindrome sentence (forms the same reading either way).",
        "Count the number of vowels in 'Airplane AI'.",
        // Domain
        "Explain transformer self-attention in plain English.",
        "What are the tradeoffs of Q4_K_M quantization for 4B-parameter models?",
        "Summarize why a sandboxed macOS app cannot call URLSession without an entitlement.",
        // Personal / stylistic
        "Give me three focus ritual ideas for deep work.",
        "Write an encouraging note for someone shipping their first app.",
        // Separators / structure
        "Produce three short paragraphs separated by '---' markdown horizontal rules.",
        "Output three bullet points, then a horizontal rule, then three more bullet points.",
        // Long-form structure
        "Give an outline (H2 headings) for a short essay on privacy.",
        "Write a JSON object describing an airplane with fields: model, seats, range_km, crew. Valid JSON only.",
        // Mixed
        "Show a code block, then a list, then a table, each labeled.",
        "Use **bold** and *italic* in one sentence. Then show a blockquote.",
        // Refusal / honest limits
        "What is the stock price of Apple right now?",
        "Open a web page and read the headline.",
        "What happened in the news today?",
    ]

    @Test func runBattery() async throws {
        guard let url = ModelLocator.bundledModelURL() ??
                URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/Sources/AirplaneAI/Resources/models/airplane-model.gguf") as URL?,
              FileManager.default.fileExists(atPath: url.path) else {
            print("→ skip: model not present")
            return
        }
        let engine = LlamaSwiftEngine()
        try await engine.loadModel(at: url, contextWindow: 2048)
        defer { Task { await engine.unloadModel() } }

        var transcript = "# Airplane AI — 50-question evaluation\n\n"
        transcript += "Model: Gemma-3n-E4B-it Q4_K_M · runtime: llama.cpp b8763\n\n"
        transcript += "Date: \(ISO8601DateFormatter().string(from: .now))\n\n---\n\n"

        for (i, prompt) in Self.prompts.enumerated() {
            let msgs = [ChatMessage(role: .user, content: prompt)]
            var params = GenerationParameters()
            params.maxTokens = 280
            params.temperature = 0.3
            params.seed = 1337
            var answer = ""
            let start = ContinuousClock.now
            do {
                for try await ev in engine.generate(messages: msgs, parameters: params.clamped()) {
                    switch ev {
                    case .token(let t): answer += t.text
                    case .finished: break
                    }
                }
            } catch { answer = "⚠️ \(error.localizedDescription)" }
            let elapsed = ContinuousClock.now - start
            transcript += "## \(i + 1). \(prompt)\n\n\(answer)\n\n_~\(elapsed) — \(answer.count) chars_\n\n---\n\n"
        }

        let outDir = URL(fileURLWithPath: "/Users/franzenzenhofer/dev/airplane-ai/build")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outFile = outDir.appendingPathComponent("eval-50.md")
        try transcript.write(to: outFile, atomically: true, encoding: .utf8)
        print("→ wrote \(outFile.path)")
    }
}
