import Foundation
import Testing
@testable import AirplaneAI

// Structural guard for LiveSpeechInput.requestSpeechAuthorization. The production
// crash (swift_task_checkIsolatedSwift trap when TCC invoked the closure on
// com.apple.root.default-qos) is a release-build runtime check that the SPM test
// target can't reproduce — tests don't enable StrictConcurrency. This test pins
// the pattern: a @MainActor caller delegating to a nonisolated static bridge that
// resumes a CheckedContinuation from a background queue. If the bridge is ever
// reverted to an instance method or the closure is allowed to inherit @MainActor,
// the shipped binary will trap again under strict concurrency.
@Suite("LiveSpeechInput isolation regression")
struct LiveSpeechInputIsolationTests {
    @Test func nonisolatedBridgeSurvivesBackgroundQueueResume() async {
        let result = await IsolationHarness.bridgedCall()
        #expect(result == true)
    }
}

@MainActor
private final class IsolationHarness {
    static func bridgedCall() async -> Bool {
        await nonisolatedBridge()
    }

    private nonisolated static func nonisolatedBridge() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .default).async {
                cont.resume(returning: true)
            }
        }
    }
}
