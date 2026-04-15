# Airplane AI v0.3.1 — Speech stability + composer performance

Reliability release focused on the voice-input pipeline and main-thread responsiveness during live transcription.

## Fixed in v0.3.1

### Speech input: three separate isolation-trap crashes
- `SFSpeechRecognizer.requestAuthorization` callback from TCC on a background queue no longer traps `swift_task_checkIsolatedSwift` — extracted into a `nonisolated static` bridge so the closure never inherits `@MainActor`.
- `AVAudioInputNode.installTap` callback on the real-time `RealtimeMessenger.mServiceQueue` no longer traps on the first audio buffer — same nonisolated bridge pattern.
- `SFSpeechRecognizer.recognitionTask` callback preemptively hardened with `@Sendable` result/error reporters; `SpeechTranscriber` actor refactored to construct the recognizer inside the nonisolated helper so the non-Sendable recognizer never crosses actor isolation.

### Composer hang during live transcription fixed at the root
- `ChatMessage` is a struct; `ForEach(Array(messages.enumerated()))` was deep-copying every message on every body re-render. At ~10Hz partial-transcript updates with 14+ messages that pegged the main thread and hung the app.
- Replaced with `ForEach(messages)` + a precomputed `Set<UUID>` of divider-before IDs — O(n) once per render, zero per-item value copies.
- Extracted composer state into `ComposerModel` (`@Observable @MainActor`). `ChatView` never reads `composer.draft` in its body, so live transcription now invalidates only the `InputBar` subtree. Profiler: zero `ChatMessage` copies and zero `AG::Subgraph::update` samples during 2s of active listening (was ~1749 of 2167 samples during the 61s hang).
- Same allocation fix applied to `AttachmentTextWindow`, `AttachmentPreviewRow`, and `MarkdownText`.

### UX polish
- Mic button pulses accent-color (blue) while recording instead of red.
- Live partial transcript is mirrored into the composer in real time.
- "Listening…" pill indicator appears above the composer while speech is active.

---

# Airplane AI v0.3.0 — Production Ready

Award-winning quality release: comprehensive E2E testing, legal compliance, live speech input, spoken responses, command-line interface, landing page, and App Store readiness.

## New in v0.3.0

### Command-line interface
- `airplaneai -p "prompt"` — single-shot prompt, streams reply to stdout
- `airplaneai -p "prompt" -n "name"` — named persistent chat
- `airplaneai -p "..." -n "name" --continue` — continue an existing chat
- `--list`, `--show`, `--delete` for chat management
- Shares the same SwiftData store as the GUI — CLI chats appear in the app
- POSIX exit codes: `0` success, `1` engine error, `2` user error, `3` named chat not found
- 20 TDD tests covering every flag and error path (closes #12)

### Spoken responses (text-to-speech)
- Speaker toggle in the toolbar next to the settings gear
- When enabled, assistant replies are read aloud via `AVSpeechSynthesizer`
- Persisted across launches, instant mute on toggle off

### First-launch onboarding
- 3-page welcome flow: Welcome, How AI Works, Legal Agreement
- Users must accept Terms of Use, Privacy Policy, and AI disclaimer before chatting
- "AI can make mistakes. Check important info." — persistent disclaimer below every chat

### Live microphone input
- Toggle mic button in toolbar (right of settings gear)
- Tap to start, tap to stop — transcript appended to composer
- Apple SFSpeechRecognizer, preferring on-device dictation when available
- Red pulse animation while recording (respects Reduce Motion)
- Permission error handling with System Settings deep link

### Legal compliance
- Privacy Policy and Terms of Use bundled as text files
- Accessible from Settings > Privacy and Settings > About
- Covers: on-device processing, zero data collection, AI limitations, user responsibility

### Testing infrastructure
- TestingInferenceEngine: rich configurable mock for E2E tests
- 30+ new tests: context exhaustion, edge cases, error recovery, stress tests
- Context manager hardened for Unicode, boundaries, attachments, concurrent access

### Landing page
- Self-contained HTML at site/index.html
- "Midnight Trust" color scheme (navy + amber + cream)
- Mobile-first responsive design
- SEO: Schema.org JSON-LD, Open Graph, Twitter Cards
- Comparison table vs ChatGPT/Claude/Gemini

### App Store readiness
- App Store description and marketing copy (docs/APP_STORE_DESCRIPTION.md)
- Comprehensive README with badges, screenshots, architecture docs
- Golden-goal spec bumped to v4.0 (multimodal finalized)
- All 10 open GitHub issues addressed

## Verified

- `swift test` — 75+ tests green across all suites
- Quality gate scripts all pass
- `codesign -d --entitlements :-` → only `app-sandbox` + `device.audio-input` + `files.user-selected.read-only`
- No network symbols in Sources/
- Schema migration V1→V2 preserves existing conversations

---

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
- Apple SFSpeechRecognizer with on-device preference when Apple provides it
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
