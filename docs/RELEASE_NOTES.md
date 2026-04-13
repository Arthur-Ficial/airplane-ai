# Airplane AI v0.2.0 — Multimodal

Airplane AI now understands images, documents, and speech — all processed on-device. The model stays Gemma 4 E4B (no downgrade). Everything the model sees is plain text.

## New in v0.2.0

### Image understanding
- Paste or drag images into the chat composer
- Apple Vision framework extracts OCR text, scene labels, and document detection — on-device
- Thumbnail preview in composer and message bubbles
- Click thumbnails for full-size preview

### Document support
- Drag PDF, Word (.docx), RTF, Markdown, code files, CSV, JSON, XML into chat
- Text extracted immediately on drop — shown as file chips in the composer
- Truncated at 32K characters with a clear marker
- Tap a chip to preview the extracted text before sending

### Speech input
- Hold-to-record mic button in the composer
- Apple SFSpeechRecognizer with `requiresOnDeviceRecognition = true`
- Transcript appended to your message draft
- Entitlement: `com.apple.security.device.audio-input` (the only addition to sandbox)

### Honest UI
- The user sees the exact extracted text that will be sent to the model
- No hidden processing — what you see is what the model gets

## Architecture

All multimodal input flows through Apple's on-device frameworks, producing plain text that the existing Gemma 4 E4B model processes. No model change, no network, no cloud.

| Input | Apple Framework | Output |
|-------|----------------|--------|
| Image | Vision (VNRecognizeTextRequest, VNClassifyImageRequest) | OCR + labels |
| PDF | PDFKit | Page text |
| Word/RTF | textutil | Extracted text |
| Text files | Direct UTF-8 read | Raw text |
| Speech | SFSpeechRecognizer | Transcript |

## Verified

- `codesign -d --entitlements :-` → only `app-sandbox` + `device.audio-input`
- No `URLSession`, `NWConnection`, or network symbols in Sources/
- 129+ tests green across domain, persistence, safety, services, integration
- Schema migration V1→V2 (attachments) preserves existing conversations

## Minimum supported hardware

- Apple Silicon Mac
- macOS 15.0+
- 16 GB unified memory

## Install

```bash
make app
open build/AirplaneAI.app
```

## License

Proprietary. Bundled Gemma weights under Google's Gemma Terms of Use.
