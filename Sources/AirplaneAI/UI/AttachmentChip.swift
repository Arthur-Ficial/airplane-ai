import SwiftUI
import AppKit

/// Visual chip for a pending DraftAttachment in the composer strip.
struct AttachmentChip: View {
    let draft: DraftAttachment
    let onRemove: () -> Void

    var body: some View {
        chipContent
            .overlay(alignment: .topTrailing) { removeButton }
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
            guard case .ready = draft.state, let att = draft.attachment else { return }
            AttachmentTextWindow.open(title: draft.filename, text: att.extractedText)
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
            stateOverlay(onImage: true)
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
            stateOverlay(onImage: false)
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
    private func stateOverlay(onImage: Bool) -> some View {
        switch draft.state {
        case .parsing:
            ProgressView().controlSize(.small)
                .tint(onImage ? .white : nil)
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

}
