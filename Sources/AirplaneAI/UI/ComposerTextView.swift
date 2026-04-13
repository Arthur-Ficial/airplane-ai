import SwiftUI
import AppKit

// NSTextView subclass that draws its own placeholder at the TEXT origin —
// same textContainer, same font, same inset → pixel-aligned with the cursor
// by construction. No separate SwiftUI overlay, no wiggle room.
final class PlaceholderTextView: NSTextView {
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }
    var onPasteImage: ((NSImage) -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        // Draw at the SAME (textContainerInset + lineFragmentPadding) origin
        // as the cursor. Both are zero here, so we start at (0,0) of the text
        // container, offset by textContainerOrigin to get back to view space.
        let origin = textContainerOrigin
        let attrString = NSAttributedString(string: placeholder, attributes: attrs)
        attrString.draw(at: origin)
    }

    // Placeholder appears/disappears with text changes — invalidate on edit.
    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    // Intercept paste to detect images before the default text handling runs.
    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        if let type = imageTypes.first(where: { pb.data(forType: $0) != nil }),
           let data = pb.data(forType: type),
           let image = NSImage(data: data) {
            onPasteImage?(image)
            return
        }
        super.paste(sender)
    }
}

// Minimal representable. textContainerInset + lineFragmentPadding both zero,
// so SwiftUI's outer padding is the SSOT for composer whitespace.
struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFocused: Bool
    var sendOnEnter: Bool
    var onSend: () -> Void
    var onCancel: () -> Void
    var onPasteImage: ((NSImage) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let tv = PlaceholderTextView(frame: .zero)
        tv.delegate = context.coordinator
        tv.font = .preferredFont(forTextStyle: .body)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer?.lineFragmentPadding = 0
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.autoresizingMask = [.width]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        tv.onPasteImage = onPasteImage

        scroll.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.parent = self
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? PlaceholderTextView else { return }
        context.coordinator.parent = self
        if tv.string != text { tv.string = text }
        if tv.placeholder != placeholder { tv.placeholder = placeholder }
        tv.onPasteImage = onPasteImage
        if isFocused, tv.window?.firstResponder !== tv {
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextView?
        weak var textView: PlaceholderTextView?

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent?.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            guard let parent else { return false }
            if sel == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            if sel == #selector(NSResponder.insertNewline(_:)) {
                let mods = NSApp.currentEvent?.modifierFlags ?? []
                if parent.sendOnEnter {
                    if mods.contains(.shift) {
                        textView.insertNewlineIgnoringFieldEditor(nil)
                    } else { parent.onSend() }
                } else {
                    if mods.contains(.command) { parent.onSend() }
                    else { textView.insertNewlineIgnoringFieldEditor(nil) }
                }
                return true
            }
            return false
        }
    }
}
