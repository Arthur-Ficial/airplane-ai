import AppKit
import Testing
@testable import AirplaneAI

@Suite("ImageAnalyzer — mock")
struct MockImageAnalyzerTests {
    @Test func returnsExpectedFormat() async throws {
        let mock = MockImageAnalyzer()
        let image = NSImage(size: NSSize(width: 1, height: 1))
        let result = try await mock.analyze(image)
        #expect(result.contains("CONTEXT:"))
        #expect(result.contains("OCR:"))
        #expect(result.contains("LABELS:"))
        #expect(result.contains("DOC:"))
    }

    @Test func throwsWhenConfigured() async {
        let mock = MockImageAnalyzer()
        mock.shouldThrow = true
        let image = NSImage(size: NSSize(width: 1, height: 1))
        await #expect(throws: AppError.self) {
            try await mock.analyze(image)
        }
    }

    @Test func returnsCustomResult() async throws {
        let mock = MockImageAnalyzer()
        mock.result = "CONTEXT: image\nOCR:\n  custom\nLABELS: a, b\nDOC: yes"
        let image = NSImage(size: NSSize(width: 1, height: 1))
        let result = try await mock.analyze(image)
        #expect(result.contains("custom"))
        #expect(result.contains("DOC: yes"))
    }
}

@Suite("ImageAnalyzer — real")
struct RealImageAnalyzerTests {
    @Test func analyzesImageWithText() async throws {
        let analyzer = ImageAnalyzer()
        let image = makeTestImage(text: "Hello World", width: 400, height: 100)
        let result = try await analyzer.analyze(image)
        #expect(result.hasPrefix("CONTEXT: image"))
        #expect(result.contains("OCR:"))
        #expect(result.contains("LABELS:"))
        #expect(result.contains("DOC:"))
    }

    @Test func analyzesBlankImage() async throws {
        let analyzer = ImageAnalyzer()
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 100, height: 100))
        image.unlockFocus()
        let result = try await analyzer.analyze(image)
        #expect(result.hasPrefix("CONTEXT: image"))
    }

    /// Draw text into an NSImage so Vision OCR has something to find.
    private func makeTestImage(text: String, width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: width, height: height))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 36),
            .foregroundColor: NSColor.black,
        ]
        (text as NSString).draw(at: NSPoint(x: 10, y: 30), withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
