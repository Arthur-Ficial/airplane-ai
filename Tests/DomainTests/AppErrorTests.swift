import Foundation
import Testing
@testable import AirplaneAI

@Suite("AppError")
struct AppErrorTests {
    @Test func equatable() {
        #expect(AppError.modelMissing == .modelMissing)
        #expect(AppError.inputTooLarge(maxTokens: 10) != .inputTooLarge(maxTokens: 11))
    }

    @Test func descriptionContainsRelevantNumbers() {
        let err = AppError.inputTooLarge(maxTokens: 1234)
        #expect((err.errorDescription ?? "").contains("1234"))
    }

    @Test func stopReasonsAreDistinct() {
        let all = Set(StopReason.allCases.map(\.rawValue))
        #expect(all.count == StopReason.allCases.count)
    }
}
