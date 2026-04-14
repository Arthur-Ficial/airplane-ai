import Foundation
import SwiftData
import Testing
@testable import AirplaneAI

/// End-to-end tests using the real model. These tests verify the full pipeline:
/// AppWiring init → boot → conversation load → model verify → load → generate.
@MainActor
@Suite(
    "Boot-to-generation e2e",
    .serialized,
    .timeLimit(.minutes(2)),
    .enabled(if: ProcessInfo.processInfo.environment["AIRPLANE_REAL_MODEL_TESTS"] != nil)
)
struct BootToGenerationTests {
    @Test func appWiringInitSucceeds() throws {
        let w = try AppWiring()
        #expect(w.state.modelState == .cold)
        #expect(w.state.chatState == .idle)
    }

    @Test func bootCompletesAndModelReady() async throws {
        let w = try AppWiring()
        await w.boot()
        #expect(w.state.modelState == .ready)
    }

    @Test(.timeLimit(.minutes(1)))
    func sendAndReceiveResponse() async throws {
        let w = try AppWiring()
        await w.boot()
        #expect(w.state.modelState == .ready)

        await w.chatController.send("Say hello in one word.")
        // Poll for response completion.
        for _ in 0..<300 {
            if w.state.chatState == .idle { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(w.state.chatState == .idle)
        let msgs = w.state.activeConversation?.messages ?? []
        let assistant = msgs.last { $0.role == .assistant }
        #expect(assistant != nil)
        #expect(!assistant!.content.isEmpty, "Model should have generated a non-empty response")
    }

    @Test func conversationPersistsAfterBoot() async throws {
        let w = try AppWiring()
        await w.boot()
        // Create a conversation and save it.
        w.state.conversations = [Conversation(title: "E2E Test")]
        try await w.store.save(w.state.conversations[0])
        // Reload from store.
        let loaded = try await w.store.allConversations()
        #expect(loaded.contains { $0.title == "E2E Test" })
    }
}
