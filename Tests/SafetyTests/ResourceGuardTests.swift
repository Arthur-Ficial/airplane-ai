import Foundation
import Testing
@testable import AirplaneAI

struct StubProbe: ResourceProbe {
    let memory: Double
    let disk: Double
    func snapshot() -> ResourceSnapshot { .init(availableMemoryGB: memory, availableDiskGB: disk) }
}

@Suite("ResourceGuard")
struct ResourceGuardTests {
    @Test func throwsOnLowMemory() {
        let g = ResourceGuard(probe: StubProbe(memory: 1, disk: 20), minMemoryGB: 4, minDiskGB: 2)
        var threw: AppError?
        do { try g.checkBeforeModelLoad() } catch let e as AppError { threw = e } catch {}
        if case .insufficientMemory = threw { } else { Issue.record("expected insufficientMemory, got \(String(describing: threw))") }
    }

    @Test func throwsOnLowDisk() {
        let g = ResourceGuard(probe: StubProbe(memory: 8, disk: 0.5), minMemoryGB: 4, minDiskGB: 2)
        var threw: AppError?
        do { try g.checkBeforeModelLoad() } catch let e as AppError { threw = e } catch {}
        if case .insufficientDisk = threw { } else { Issue.record("expected insufficientDisk") }
    }

    @Test func passesWhenResourcesAmple() throws {
        let g = ResourceGuard(probe: StubProbe(memory: 16, disk: 100), minMemoryGB: 4, minDiskGB: 2)
        try g.checkBeforeModelLoad()
    }
}
