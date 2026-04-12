import Foundation
import Testing
import CryptoKit
@testable import AirplaneAI

@Suite("ModelIntegrity")
struct ModelIntegrityTests {
    @Test func streamingSha256MatchesWholeFileHash() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("payload.bin")
        let payload = Data((0..<(4 * 1024 * 1024)).map { UInt8($0 & 0xFF) })
        try payload.write(to: file)

        let expected = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        let actual = try ModelIntegrity().sha256(of: file, chunkBytes: 1024 * 1024)
        #expect(actual == expected)
    }

    @Test func verifyThrowsOnMismatch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("payload.bin")
        try Data([1, 2, 3]).write(to: file)
        var threw = false
        do { try ModelIntegrity().verify(file: file, expected: String(repeating: "0", count: 64)) }
        catch AppError.modelVerificationFailed { threw = true }
        catch {}
        #expect(threw)
    }

    @Test func cacheKeyIsStableForSameInputs() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manifest = dir.appendingPathComponent("m.json")
        let model = dir.appendingPathComponent("m.gguf")
        try Data("{}".utf8).write(to: manifest)
        try Data(repeating: 0, count: 128).write(to: model)

        let a = try ModelIntegrityCacheKey.compute(appBuild: "1", manifest: manifest, file: model)
        let b = try ModelIntegrityCacheKey.compute(appBuild: "1", manifest: manifest, file: model)
        #expect(a == b)

        // Different app build → different key.
        let c = try ModelIntegrityCacheKey.compute(appBuild: "2", manifest: manifest, file: model)
        #expect(a != c)
    }
}
