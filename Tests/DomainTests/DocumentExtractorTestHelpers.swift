import Foundation
import PDFKit

/// Helpers for creating temporary test files for DocumentExtractorTests.
enum DocumentTestHelpers {
    static func makeTempFile(name: String, content: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func makeTempPDF(text: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        let url = dir.appendingPathComponent("test.pdf")
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var rect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = CGContext(consumer: consumer, mediaBox: &rect, nil)!
        context.beginPage(mediaBox: &rect)
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: 72, y: 720)
        CTLineDraw(line, context)
        context.endPage()
        context.closePDF()
        try! data.write(to: url, atomically: true)
        return url
    }
}
