import SwiftUI
import AppKit

/// Horizontal row of attachment previews shown inside a message bubble.
struct AttachmentPreviewRow: View {
    let attachments: [Attachment]

    var body: some View {
        HStack(spacing: Metrics.Padding.small) {
            ForEach(attachments) { att in
                attachmentView(att)
                    .onTapGesture { openPreview(att) }
            }
        }
    }

    @ViewBuilder
    private func attachmentView(_ att: Attachment) -> some View {
        switch att {
        case .image(let data, _):
            if let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
            }
        case .document(_, let name, _):
            HStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(for: .data))
                    .resizable().frame(width: 16, height: 16)
                Text(name)
                    .font(.caption2).lineLimit(1)
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
        case .audio:
            Label("Audio", systemImage: "waveform")
                .font(.caption2)
                .foregroundColor(Color(nsColor: .labelColor))
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
        }
    }

    private func openPreview(_ att: Attachment) {
        let title: String
        switch att {
        case .image(_, _): title = "Image — Extracted Text"
        case .document(_, let name, _): title = name
        case .audio(_): title = "Audio Transcript"
        }
        AttachmentTextWindow.open(title: title, text: att.extractedText)
    }
}

extension Attachment: Identifiable {
    public var id: String {
        switch self {
        case .image(let data, _): return "img-\(data.hashValue)"
        case .document(_, let name, _): return "doc-\(name)"
        case .audio(let t): return "audio-\(t.hashValue)"
        }
    }
}
