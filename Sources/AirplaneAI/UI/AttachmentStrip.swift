import SwiftUI

/// Horizontal scroll of AttachmentChips above the composer text input.
struct AttachmentStrip: View {
    let drafts: [DraftAttachment]
    let onRemove: (DraftAttachment) -> Void

    var body: some View {
        if !drafts.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Metrics.Padding.small) {
                    ForEach(drafts) { draft in
                        AttachmentChip(draft: draft, onRemove: { onRemove(draft) })
                    }
                }
                .padding(.horizontal, Metrics.Padding.small)
                .padding(.vertical, Metrics.Padding.tight)
            }
        }
    }
}
