import SwiftUI
import AppKit

/// Visual chip for a pending DraftAttachment in the composer strip.
struct AttachmentChip: View {
    let draft: DraftAttachment
    let onRemove: () -> Void
    @State private var showPopover = false

    var body: some View {
        chipContent
            .overlay(alignment: .topTrailing) { removeButton }
            .popover(isPresented: $showPopover) { previewPopover }
    }

    @ViewBuilder
    private var chipContent: some View {
        Group {
            if draft.thumbnail != nil {
                imageChip
            } else {
                documentChip
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if case .ready = draft.state { showPopover = true }
        }
    }

    private var imageChip: some View {
        ZStack {
            if let img = draft.thumbnail {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
            }
            stateOverlay
        }
        .frame(width: 48, height: 48)
    }

    private var documentChip: some View {
        HStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(for: .data))
                .resizable().frame(width: 20, height: 20)
            Text(draft.filename)
                .font(.caption2).lineLimit(1)
                .foregroundStyle(.primary)
            stateOverlay
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: Metrics.Radius.small))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.Radius.small)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch draft.state {
        case .parsing:
            ProgressView().controlSize(.small)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red).font(.caption)
        case .ready:
            EmptyView()
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .background(Circle().fill(Color(nsColor: .windowBackgroundColor)))
        }
        .buttonStyle(.plain)
        .offset(x: 4, y: -4)
        .help("Remove attachment")
    }

    private var previewPopover: some View {
        ScrollView {
            Text(previewText)
                .font(.caption).padding()
                .frame(maxWidth: 300, alignment: .leading)
        }
        .frame(maxHeight: 200)
    }

    private var previewText: String {
        guard let att = draft.attachment else { return "" }
        let text = att.extractedText
        return text.count > 500 ? String(text.prefix(500)) + "…" : text
    }
}
