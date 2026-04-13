import Foundation
import Testing
@testable import AirplaneAI

/// Verify the binary contains no forbidden network symbols.
@Suite("Network isolation")
struct NetworkIsolationTests {
    @Test func noForbiddenNetworkSymbolsInSources() throws {
        // Check Swift source files for forbidden symbols.
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let sourcesDir = root.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: sourcesDir.path) else {
            // Skip if not running from project root (e.g., in CI).
            return
        }
        let forbidden = ["URLSession", "NWConnection", "NWListener", "WKWebView", "Sparkle"]
        let enumerator = FileManager.default.enumerator(atPath: sourcesDir.path)
        while let file = enumerator?.nextObject() as? String {
            guard file.hasSuffix(".swift") else { continue }
            let path = sourcesDir.appendingPathComponent(file)
            let content = try String(contentsOf: path, encoding: .utf8)
            for sym in forbidden {
                let lines = content.components(separatedBy: .newlines)
                for (i, line) in lines.enumerated() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") { continue }
                    #expect(!line.contains(sym), "Forbidden symbol '\(sym)' found in \(file):\(i+1)")
                }
            }
        }
    }

    @Test func entitlementsOnlyAllowSandboxAndAudio() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let entPath = root.appendingPathComponent("AirplaneAI.entitlements")
        guard FileManager.default.fileExists(atPath: entPath.path) else { return }
        let content = try String(contentsOf: entPath, encoding: .utf8)
        let allowed = ["com.apple.security.app-sandbox", "com.apple.security.device.audio-input"]
        // Extract all keys.
        let pattern = try NSRegularExpression(pattern: "<key>([^<]+)</key>")
        let matches = pattern.matches(in: content, range: NSRange(content.startIndex..., in: content))
        let keys = matches.compactMap { m -> String? in
            guard let range = Range(m.range(at: 1), in: content) else { return nil }
            return String(content[range])
        }
        for key in keys {
            #expect(allowed.contains(key), "Forbidden entitlement: \(key)")
        }
    }
}
