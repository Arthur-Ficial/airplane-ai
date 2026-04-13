# Attachment UI Fixes — Design Spec
**Date:** 2026-04-13

## Problem
1. Drag-and-drop shows raw strings instead of image thumbnails
2. No file picker button — users must drag or paste
3. Spinner in AttachmentChip is black on dark thumbnail background — invisible
4. Unsupported file types silently dropped

## Root Causes
1. **Drop handler** uses `loadItem(forTypeIdentifier:)` with `item as? Data` cast — fails for some NSItemProvider formats (e.g. Safari images provide NSImage, not Data). Also, `UTType.image` branch never fires because `UTType.fileURL` matches first for all Finder drags.
2. **No file picker** — InputBar has no attach button.
3. **Spinner tint** — `ProgressView().controlSize(.small)` uses system default (dark) tint, invisible against image thumbnails.
4. **ChatController.addFileDraft** — falls through silently when extension not in SupportedFormats.

## Fixes
1. **Drop handler**: Use `loadObject(ofClass: NSURL.self)` for file URLs and `loadObject(ofClass: NSImage.self)` for direct images. More robust than raw `loadItem`.
2. **File picker**: Add paperclip button in InputBar, left of composer. Opens `NSOpenPanel` with `SupportedFormats.allExtensions`. Routes through `controller.addFileDraft(url:)`.
3. **Spinner**: Pass `isImageChip` context to stateOverlay. Use `.tint(.white)` on image chip spinners.
4. **Unsupported fallback**: Try `String(contentsOf:)` for unknown extensions. If readable, treat as plain text document. If not, create error-state draft.

## Files to Change
- `Sources/AirplaneAI/UI/ChatView.swift` — handleDrop, InputBar (add attach button)
- `Sources/AirplaneAI/UI/AttachmentChip.swift` — spinner tint
- `Sources/AirplaneAI/App/ChatController.swift` — addFileDraft fallback
- `Sources/AirplaneAI/Services/SupportedFormats.swift` — add allExtensions, allUTTypes
- `Tests/ChatTests/ChatControllerTests.swift` — TDD tests for attachment flows
