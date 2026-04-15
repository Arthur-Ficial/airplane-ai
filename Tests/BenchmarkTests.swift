import Foundation
import Testing
@testable import AirplaneAI

@Suite(
    "Benchmarks",
    .enabled(if: ProcessInfo.processInfo.environment["AIRPLANE_BENCHMARKS"] != nil)
)
struct CoreBenchmarkTests {
    @Test("ContextManager benchmark stays within baseline")
    func contextManagerBenchmark() async throws {
        let baseline = try loadBaseline(named: "context_fit_200_messages")
        let manager = ContextManager(maxContextTokens: 8192)
        let counter = FixedTokenCounter()
        let messages = sampleMessages(count: 200)

        let milliseconds = try await measure(iterations: baseline.iterations) {
            _ = try await manager.fitToContext(
                systemPrompt: "You are Airplane AI.",
                messages: messages,
                tokenCounter: counter
            )
        }

        #expect(milliseconds <= threshold(for: baseline))
    }

    @Test("OutputSanitizer benchmark stays within baseline")
    func outputSanitizerBenchmark() async throws {
        let baseline = try loadBaseline(named: "output_sanitizer_10000_chunks")
        let chunks = (0..<10_000).map { index in
            TokenChunk(text: " chunk\(index)\n", tokenID: Int32(index % 7), index: index)
        }

        let milliseconds = try await measure(iterations: baseline.iterations) {
            let sanitizer = OutputSanitizer(maxOutputTokens: 20_000)
            for chunk in chunks {
                _ = sanitizer.check(chunk)
            }
        }

        #expect(milliseconds <= threshold(for: baseline))
    }

    @Test("PromptFormatter benchmark stays within baseline")
    func promptFormatterBenchmark() async throws {
        let baseline = try loadBaseline(named: "prompt_formatter_200_messages")
        let formatter = PromptFormatter()
        let messages = sampleMessages(count: 200)

        let milliseconds = try await measure(iterations: baseline.iterations) {
            _ = formatter.format(
                systemPrompt: "You are Airplane AI.",
                messages: messages,
                model: nil
            )
        }

        #expect(milliseconds <= threshold(for: baseline))
    }

    private func threshold(for baseline: BenchmarkBaseline) -> Double {
        baseline.maxMilliseconds * (1 + baseline.tolerancePercent / 100)
    }

    private func loadBaseline(named name: String) throws -> BenchmarkBaseline {
        let url = URL(fileURLWithPath: "Benchmarks/baselines/core.json")
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(BenchmarkBaselineFile.self, from: data)
        guard let entry = file.benchmarks.first(where: { $0.name == name }) else {
            throw BenchmarkFailure.missingBaseline(name)
        }
        return BenchmarkBaseline(
            name: entry.name,
            maxMilliseconds: entry.maxMilliseconds,
            iterations: entry.iterations,
            tolerancePercent: file.tolerancePercent
        )
    }

    private func sampleMessages(count: Int) -> [ChatMessage] {
        (0..<count).map { index in
            let role: MessageRole = index.isMultiple(of: 2) ? .user : .assistant
            return ChatMessage(
                role: role,
                content: "Message \(index) with enough content to keep formatting and token counting honest."
            )
        }
    }

    private func measure(
        iterations: Int,
        body: () async throws -> Void
    ) async throws -> Double {
        try await body()
        let start = ContinuousClock.now
        for _ in 0..<iterations {
            try await body()
        }
        let duration = start.duration(to: .now)
        let totalMilliseconds = Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1_000_000_000_000_000
        return totalMilliseconds / Double(iterations)
    }
}

private actor FixedTokenCounter: TokenCounter {
    func countTokens(in text: String) async throws -> Int {
        max(1, text.count / 4)
    }
}

private struct BenchmarkBaselineFile: Decodable {
    struct Entry: Decodable {
        let name: String
        let maxMilliseconds: Double
        let iterations: Int
    }

    let version: Int
    let tolerancePercent: Double
    let benchmarks: [Entry]
}

private struct BenchmarkBaseline {
    let name: String
    let maxMilliseconds: Double
    let iterations: Int
    let tolerancePercent: Double
}

private enum BenchmarkFailure: Error {
    case missingBaseline(String)
}
