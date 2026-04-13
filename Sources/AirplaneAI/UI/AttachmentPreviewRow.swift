import SwiftUI
import AppKit

/// Horizontal row of attachment previews shown inside a message bubble.
struct AttachmentPreviewRow: View {
    let attachments: [Attachment]
    @State private var selectedAttachment: Attachment?

    var body: some View {
        HStack(spacing: Metrics.Padding.small) {
            ForEach(Array(attachments.enumerated()), id: \.offset) { _, att in
                attachmentView(att)
                    .onTapGesture { selectedAttachment = att }
            }
        }
        .sheet(item: $selectedAttachment) { att in
            attachmentDetail(att)
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
                Text(name).font(.caption2).lineLimit(1)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
        case .audio:
            Label("Audio", systemImage: "waveform")
                .font(.caption2)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
        }
    }

    @ViewBuilder
    private func attachmentDetail(_ att: Attachment) -> some View {
        switch att {
        case .image(let data, let text):
            imageDetail(data: data, text: text)
        case .document(let text, let name, _):
            textDetail(title: name, text: text)
        case .audio(let transcript):
            textDetail(title: "Audio Transcript", text: transcript)
        }
    }

    private func imageDetail(data: Data, text: String) -> some View {
        VStack(spacing: 0) {
            if let img = NSImage(data: data) {
                Image(nsImage: img).resizable().scaledToFit()
                    .frame(maxWidth: 500, maxHeight: 400)
            }
            if !text.isEmpty {
                ScrollView { Text(text).font(.caption).padding() }
                    .frame(maxHeight: 150)
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }

    private func textDetail(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Metrics.Padding.small) {
            Text(title).font(.headline).padding(.horizontal)
            ScrollView {
                Text(text).font(.body).textSelection(.enabled).padding()
            }
        }
        .frame(minWidth: 400, minHeight: 300, maxHeight: 500)
    }
}

// Attachment needs Identifiable for the sheet binding.
extension Attachment: Identifiable {
    public var id: String {
        switch self {
        case .image(let data, _): return "img-\(data.hashValue)"
        case .document(_, let name, _): return "doc-\(name)"
        case .audio(let t): return "audio-\(t.hashValue)"
        }
    }
}
