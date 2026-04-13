# Airplane AI

Paid, local-first macOS chat app with multimodal input. One bundled model (Gemma 4 E4B via pinned llama.cpp). Zero network. Zero telemetry. Sandboxed.

## Features

- **Offline AI chat** — Gemma 4 E4B runs entirely on your Mac via Metal GPU
- **Image understanding** — paste or drag images; Apple Vision extracts OCR text and labels on-device
- **Document support** — drag PDF, Word, Markdown, code files, CSV, JSON into chat
- **Speech input** — hold-to-record mic button; Apple SFSpeechRecognizer transcribes on-device
- **Privacy first** — no network, no telemetry, no cloud. Everything stays on your Mac
- **Apple Silicon** — optimized for 16 GB+ unified memory Macs

## Build

```bash
make app        # fetches model (if needed), builds AirplaneAI.app
make run        # build + launch
make test       # run tests
make verify     # CI verification scripts
```

First-time setup on a new machine:

```bash
./scripts/setup-dev.sh
```

## Multimodal Architecture

All input is converted to plain text before reaching the model:

| Input | Processor | Output |
|-------|-----------|--------|
| Image (paste/drag) | Apple Vision (on-device OCR + labels) | Structured text block |
| PDF | PDFKit | Extracted page text |
| Word (.docx) | textutil | Extracted text |
| Markdown/TXT/code | Direct read | Raw text |
| Speech | SFSpeechRecognizer (on-device) | Transcript |

The model only ever sees text. No model downgrade for multimodal — Gemma 4 E4B stays the sole inference engine.

## Docs

- `CLAUDE.md` — build instructions for AI agents (mindset + developer requirements)
- `briefing/golden-goal.md` — full product + engineering spec
- `docs/BUILD.md` — detailed build guide and prerequisites

## License

Proprietary. Bundled model license in `Sources/AirplaneAI/Resources/licenses/`.
