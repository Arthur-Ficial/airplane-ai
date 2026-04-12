import Foundation
import Testing
@testable import AirplaneAI

@Suite("RuntimeProfileProvider")
struct RuntimeProfileTests {
    @Test func memoryClassBoundaries() {
        #expect(MemoryClass.from(unifiedMemoryGB: 8) == .unsupported8to15)
        #expect(MemoryClass.from(unifiedMemoryGB: 15) == .unsupported8to15)
        #expect(MemoryClass.from(unifiedMemoryGB: 16) == .supported16to23)
        #expect(MemoryClass.from(unifiedMemoryGB: 23) == .supported16to23)
        #expect(MemoryClass.from(unifiedMemoryGB: 24) == .supported24to31)
        #expect(MemoryClass.from(unifiedMemoryGB: 32) == .supported32to63)
        #expect(MemoryClass.from(unifiedMemoryGB: 64) == .supported64plus)
        #expect(MemoryClass.from(unifiedMemoryGB: 128) == .supported64plus)
    }

    @Test func sixteenGBHitsSupportedMinimum() {
        let p = RuntimeProfileProvider().profile(for: .supported16to23)
        #expect(p.defaultContext == 8192)
        #expect(p.maxSupportedContext == 8192)
        #expect(p.warmupEnabled)
    }

    @Test func unsupportedClassStillReturnsAProfileButFlaggedUnsupported() {
        let p = RuntimeProfileProvider().profile(for: .unsupported8to15)
        #expect(!p.memoryClass.isSupported)
        #expect(p.gpuLayerPolicy == .none)
    }
}
