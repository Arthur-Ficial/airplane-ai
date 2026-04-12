import Foundation
import CryptoKit

public struct ModelIntegrity: Sendable {
    public init() {}

    // Incremental streaming SHA-256 — never loads full file.
    public func sha256(of file: URL, chunkBytes: Int = 8 * 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: chunkBytes) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    public func verify(file: URL, expected: String) throws {
        let actual = try sha256(of: file)
        if actual.lowercased() != expected.lowercased() {
            throw AppError.modelVerificationFailed
        }
    }
}

// Cache key = appBuild + manifest hash + file mtime + file size.
// Spec §12.6: only re-verify when any key changes.
public struct ModelIntegrityCacheKey: Codable, Sendable, Equatable {
    public let appBuild: String
    public let manifestSha: String
    public let fileSize: Int64
    public let fileMtimeEpoch: Int64

    public static func compute(appBuild: String, manifest: URL, file: URL) throws -> ModelIntegrityCacheKey {
        let manifestData = try Data(contentsOf: manifest)
        let manifestSha = SHA256.hash(data: manifestData).map { String(format: "%02x", $0) }.joined()
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return ModelIntegrityCacheKey(
            appBuild: appBuild,
            manifestSha: manifestSha,
            fileSize: size,
            fileMtimeEpoch: Int64(mtime)
        )
    }
}
