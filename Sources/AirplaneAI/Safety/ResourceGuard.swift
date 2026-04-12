import Foundation

public struct ResourceSnapshot: Sendable, Equatable {
    public let availableMemoryGB: Double
    public let availableDiskGB: Double
    public init(availableMemoryGB: Double, availableDiskGB: Double) {
        self.availableMemoryGB = availableMemoryGB
        self.availableDiskGB = availableDiskGB
    }
}

public protocol ResourceProbe: Sendable {
    func snapshot() -> ResourceSnapshot
}

public struct SystemResourceProbe: ResourceProbe {
    public init() {}
    public func snapshot() -> ResourceSnapshot {
        ResourceSnapshot(
            availableMemoryGB: Self.availableMemoryGB(),
            availableDiskGB: Self.availableDiskGB()
        )
    }

    static func availableMemoryGB() -> Double {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        // Page size is immutable at runtime — read via sysconf for concurrency safety.
        let pageSize = Double(sysconf(_SC_PAGESIZE))
        let free = Double(stats.free_count) * pageSize
        let inactive = Double(stats.inactive_count) * pageSize
        return (free + inactive) / 1_073_741_824.0
    }

    static func availableDiskGB() -> Double {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            return Double(available) / 1_073_741_824.0
        }
        return 0
    }
}

public struct ResourceGuard: Sendable {
    public let probe: any ResourceProbe
    public let minMemoryGB: Double
    public let minDiskGB: Double

    public init(probe: any ResourceProbe = SystemResourceProbe(), minMemoryGB: Double = 4.0, minDiskGB: Double = 2.0) {
        self.probe = probe
        self.minMemoryGB = minMemoryGB
        self.minDiskGB = minDiskGB
    }

    public func checkBeforeModelLoad() throws {
        let s = probe.snapshot()
        if s.availableMemoryGB < minMemoryGB {
            throw AppError.insufficientMemory(requiredGB: minMemoryGB, availableGB: s.availableMemoryGB)
        }
        if s.availableDiskGB < minDiskGB {
            throw AppError.insufficientDisk(requiredGB: minDiskGB, availableGB: s.availableDiskGB)
        }
    }
}
