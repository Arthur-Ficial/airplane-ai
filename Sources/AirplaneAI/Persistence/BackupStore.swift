import Foundation

// Local-only rolling snapshots (spec §13). Keeps the last N snapshots inside the sandbox.
public struct BackupStore: Sendable {
    public let directory: URL
    public let maxSnapshots: Int

    public init(directory: URL, maxSnapshots: Int = 10) {
        self.directory = directory
        self.maxSnapshots = maxSnapshots
    }

    private var fileManager: FileManager { FileManager.default }

    public func write(_ conversations: [Conversation]) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(conversations)
        let name = Self.filename(at: .now)
        let url = directory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        try pruneOldSnapshots()
    }

    public func readLatest() throws -> [Conversation]? {
        let files = try listSnapshots()
        guard let newest = files.first else { return nil }
        let data = try Data(contentsOf: newest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Conversation].self, from: data)
    }

    func listSnapshots() throws -> [URL] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
        return items
            .filter { $0.lastPathComponent.hasPrefix("snapshot-") && $0.pathExtension == "json" }
            .sorted { a, b in
                let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return aDate > bDate
            }
    }

    private func pruneOldSnapshots() throws {
        let files = try listSnapshots()
        for f in files.dropFirst(maxSnapshots) { try fileManager.removeItem(at: f) }
    }

    static func filename(at date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "snapshot-\(formatter.string(from: date)).json"
    }
}
