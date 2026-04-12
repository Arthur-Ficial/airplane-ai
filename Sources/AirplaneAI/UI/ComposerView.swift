import SwiftUI
import AppKit

// NSTextView-backed multiline composer. Spec §14: Enter sends, Shift+Enter newline.
struct ComposerView: NSViewRepresentable {
    @Binding var text: String
    var isGenerating: Bool
    var onSubmit: () -> Void
    var onStop: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 14)
        tv.isRichText = false
        tv.allowsUndo = true
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        context.coordinator.textView = tv
        context.coordinator.parent = self
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = nsView.documentView as? NSTextView else { return }
        if tv.string != text { tv.string = text }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerView?
        weak var textView: NSTextView?

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent?.text = tv.string
        }

        func textView(_ textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                let event = NSApp.currentEvent
                let shift = event?.modifierFlags.contains(.shift) ?? false
                if shift {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    if parent?.isGenerating == true {
                        parent?.onStop()
                    } else {
                        parent?.onSubmit()
                    }
                }
                return true
            }
            return false
        }
    }
}
