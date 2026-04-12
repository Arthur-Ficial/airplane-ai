import Foundation
import Testing
@testable import AirplaneAI

@Suite("KVCostEstimator")
struct KVCostEstimatorTests {
    @Test func bytesAtEightKIsAboutOnePointOneGB() {
        // Gemma-3n-E4B: ~140 KB/token at F16.
        let bytes = KVCostEstimator.bytes(forContext: 8192)
        // 1.1 GB ± 100 MB
        let gb = Double(bytes) / 1_073_741_824.0
        #expect(gb > 0.9 && gb < 1.3, "expected ~1.1 GB, got \(gb)")
    }

    @Test func bytesAtThirtyTwoKIsAboutFourPointSixGB() {
        let bytes = KVCostEstimator.bytes(forContext: 32768)
        let gb = Double(bytes) / 1_073_741_824.0
        #expect(gb > 4.0 && gb < 5.2, "expected ~4.6 GB, got \(gb)")
    }

    @Test func humanReadableFormats() {
        #expect(KVCostEstimator.humanReadable(context: 4096).contains("GB")
             || KVCostEstimator.humanReadable(context: 4096).contains("MB"))
        #expect(KVCostEstimator.humanReadable(context: 32768).contains("GB"))
    }

    @Test func monotonicGrowth() {
        #expect(KVCostEstimator.bytes(forContext: 4096)
              < KVCostEstimator.bytes(forContext: 8192))
        #expect(KVCostEstimator.bytes(forContext: 8192)
              < KVCostEstimator.bytes(forContext: 16384))
    }
}
