import AppKit
import SwiftUI

struct OnboardingLegalReviewPage: View {
    let document: OnboardingLegalDocument
    @Binding var reviewed: Bool

    private var statusText: String {
        reviewed ? "Review complete" : "Scroll to the end of the full document to continue."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(document.title)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 10) {
                Text(document.summaryIntro)
                    .font(.callout.weight(.medium))
                ForEach(document.summaryBullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Palette.accent)
                            .padding(.top, 2)
                        Text(bullet)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Full text")
                    .font(.callout.weight(.semibold))
                ScrollCompletionTextView(
                    text: LegalDocumentLoader.load(resourceName: document.resourceName, fallbackTitle: document.title),
                    onReachedEnd: { reviewed = true }
                )
                .frame(minHeight: 240)

                Label(statusText, systemImage: reviewed ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(reviewed ? .green : .secondary)
            }

            Spacer()
        }
        .padding(Metrics.Padding.large * 2)
    }
}

private struct ScrollCompletionTextView: NSViewRepresentable {
    let text: String
    let onReachedEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onReachedEnd: onReachedEnd)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.attach(to: scrollView)
        context.coordinator.evaluate(scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let textView = scrollView.documentView as? NSTextView, textView.string != text {
            textView.string = text
        }
        context.coordinator.onReachedEnd = onReachedEnd
        context.coordinator.evaluate(scrollView)
    }

    @MainActor
    final class Coordinator: NSObject {
        var onReachedEnd: () -> Void
        private weak var scrollView: NSScrollView?
        private weak var observedContentView: NSClipView?
        private var didReachEnd = false

        init(onReachedEnd: @escaping () -> Void) {
            self.onReachedEnd = onReachedEnd
        }

        deinit {
            if let contentView = observedContentView {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: contentView)
            }
        }

        func attach(to scrollView: NSScrollView) {
            if let oldContentView = observedContentView {
                NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: oldContentView)
            }
            self.scrollView = scrollView
            observedContentView = scrollView.contentView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: observedContentView
            )
        }

        @objc private func boundsDidChange() {
            guard let scrollView else { return }
            evaluate(scrollView)
        }

        func evaluate(_ scrollView: NSScrollView) {
            guard !didReachEnd else { return }
            guard let documentView = scrollView.documentView else { return }

            let visibleRect = scrollView.contentView.documentVisibleRect
            let contentHeight = documentView.bounds.maxY
            let bottomThreshold = max(0, contentHeight - 12)

            if visibleRect.maxY >= bottomThreshold {
                didReachEnd = true
                onReachedEnd()
            }
        }
    }
}
