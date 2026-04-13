import SwiftUI

/// Horizontal scroll of AttachmentChips above the composer text input.
struct AttachmentStrip: View {
    let drafts: [DraftAttachment]
    let onRemove: (DraftAttachment) -> Void

    var body: some View {
        if !drafts.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Metrics.Padding.small) {
                        ForEach(drafts) { draft in
                            AttachmentChip(draft: draft, onRemove: { onRemove(draft) })
                        }
                    }
                    .padding(.horizontal, Metrics.Composer.horizontalPadding)
                    .padding(.top, Metrics.Padding.tight)
                }
                let total = drafts.compactMap(\.tokenCount).reduce(0, +)
                if total > 0 {
                    Text(L.tokensInAttachments(total))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Metrics.Composer.horizontalPadding)
                        .padding(.bottom, 2)
                }
            }
        }
    }
}
