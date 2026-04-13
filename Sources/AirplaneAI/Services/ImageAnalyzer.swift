import AppKit
import Vision

/// Analyzes images on-device using Apple Vision framework.
/// Returns structured text: OCR lines, classification labels, document detection.
public struct ImageAnalyzer: ImageAnalyzing, Sendable {
    public init() {}

    public func analyze(_ image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AppError.generationFailed(summary: "Cannot convert image to CGImage")
        }
        async let ocrLines = recognizeText(in: cgImage)
        async let labels = classifyImage(cgImage)
        async let isDoc = detectDocument(in: cgImage)
        return try await formatResult(ocr: ocrLines, labels: labels, isDocument: isDoc)
    }
}

// MARK: - Vision requests

extension ImageAnalyzer {
    private func recognizeText(in cgImage: CGImage) async throws -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    private func classifyImage(_ cgImage: CGImage) async throws -> [String] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        let top5 = (request.results ?? [])
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
        return top5.map(\.identifier)
    }

    private func detectDocument(in cgImage: CGImage) async throws -> Bool {
        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        return (request.results ?? []).first?.confidence ?? 0 > 0.5
    }
}

// MARK: - Formatting

extension ImageAnalyzer {
    private func formatResult(ocr: [String], labels: [String], isDocument: Bool) -> String {
        var parts = ["CONTEXT: image", "OCR:"]
        if ocr.isEmpty {
            parts.append("  (none)")
        } else {
            parts.append(contentsOf: ocr.map { "  \($0)" })
        }
        let labelStr = labels.isEmpty ? "(none)" : labels.joined(separator: ", ")
        parts.append("LABELS: \(labelStr)")
        parts.append("DOC: \(isDocument ? "yes" : "no")")
        return parts.joined(separator: "\n")
    }
}
