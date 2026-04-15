<p align="center">
  <img src="site/img/icon.png" alt="Airplane AI" width="128">
</p>

<h1 align="center">Airplane AI</h1>

<p align="center">
  <strong>Private offline AI chat for macOS</strong><br>
  <em>AI that never phones home.</em>
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-macOS%2015%2B-blue">
  <img alt="Architecture" src="https://img.shields.io/badge/arch-Apple%20Silicon-orange">
  <img alt="Swift" src="https://img.shields.io/badge/swift-6.0-F05138">
  <img alt="License" src="https://img.shields.io/badge/license-Proprietary-lightgrey">
</p>

---

## What is Airplane AI?

Airplane AI is a paid, local-first macOS chat app. It ships one bundled model -- Google's Gemma 4 E4B instruction-tuned, quantized to Q4_K_M -- and runs it entirely on your Mac through llama.cpp and Metal GPU acceleration. There is no server, no account, no telemetry, and no internet connection at runtime. Your conversations never leave your machine. Period.

<p align="center">
  <img src="site/img/screen-hero.png" alt="Airplane AI — main chat window" width="700">
</p>

## Features

- **Completely offline AI** -- Gemma 4 E4B runs on-device via Metal GPU. No cloud. No network entitlements. Kernel-enforced sandbox.
- **Image understanding** -- paste or drag images into the composer. Apple Vision extracts OCR text and scene labels on-device. The model sees only the extracted text.
- **Document support** -- drag PDF, Word, Markdown, code files, CSV, or JSON into chat. Text is extracted immediately and shown before sending.
- **Speech input** -- tap the mic button to dictate into the composer. Airplane AI uses Apple speech recognition and prefers on-device dictation whenever Apple provides it for the selected language.
- **Privacy by architecture** -- App Sandbox enabled, zero network entitlements, zero telemetry, zero analytics, zero crash SDKs. CI scripts verify this on every build.
- **Streaming Markdown** -- responses stream token-by-token with live Markdown rendering. Code blocks, lists, emphasis -- all rendered as they arrive.
- **Conversation history** -- SwiftData persistence with versioned schemas and migration plans. Your chats survive restarts, sleep/wake, and app updates.
- **Honest AI** -- the system prompt tells the model it is offline and local. No fake citations, no invented links, no claims of internet access. The UI shows you exactly what the model sees.
- **Apple Silicon optimized** -- runtime profiles tuned per memory class. 16 GB, 24 GB, 32 GB, and 64 GB+ machines each get context windows and GPU offload calibrated to their hardware.
- **Single purchase** -- one-time purchase from the Mac App Store. No subscriptions, no in-app purchases, no freemium.

## Screenshots

| | |
|---|---|
| ![Chat conversation](site/img/screen-chat.png) **Chat** -- clean single-window interface with streaming Markdown | ![Sidebar](site/img/screen-sidebar.png) **Conversations** -- sidebar with full history and search |
| ![Image input](site/img/screen-image.png) **Images** -- paste an image, see extracted text before sending | ![Settings](site/img/screen-settings.png) **Settings** -- runtime profile, context window, model info |

## Requirements

| Requirement | Minimum |
|---|---|
| Operating system | macOS 15.0 (Sequoia) or later |
| Processor | Apple Silicon (M1 or later) |
| Memory | 16 GB unified memory |
| Disk space | ~5 GB (app + bundled model) |

Macs with 8 GB of memory are not supported. The bundled Gemma 4 E4B model requires approximately 5 GB just to load at Q4 quantization, before context windows, app memory, and macOS overhead. 16 GB is the engineering-validated minimum for a stable consumer experience.

## Install

### Mac App Store (recommended)

[![Download on the Mac App Store](https://developer.apple.com/assets/elements/badges/download-on-the-mac-app-store.svg)](https://apps.apple.com/app/airplane-ai/id000000000)

### Build from source

```bash
git clone https://github.com/Arthur-Ficial/airplane-ai.git
cd airplane-ai
./scripts/setup-dev.sh    # install prerequisites
make app                  # build AirplaneAI.app (warm rebuilds are near-instant)
open build/AirplaneAI.app
```

Building from source requires Xcode 16+, Swift 6, and an Apple Silicon Mac. The model (~4.5 GB) is fetched once during the first build.

## Command line

The same `.app` binary also runs headless from the terminal. The CLI shares the SwiftData store with the GUI — chats you create from the terminal show up when you open the app.

```bash
# Single-shot (not persisted)
airplaneai -p "What is 2+2?"

# Named persistent chat
airplaneai -p "Explain closures" -n "swift-learning"

# Replace an existing named chat with a fresh one
airplaneai -p "Start over from scratch" -n "swift-learning" --new

# Continue the same chat
airplaneai -p "Now give me an example" -n "swift-learning" --continue

# JSON output for scripts
airplaneai -p "Summarize this repo" --json

# Housekeeping
airplaneai --list
airplaneai --show -n "swift-learning"
airplaneai --delete -n "swift-learning"
```

Exit codes: `0` success, `1` engine error, `2` user error, `3` named chat not found.

Install the GUI app and CLI symlink together with:

```bash
make install
```

## Architecture

```
UI Layer            SwiftUI + AppKit wrappers
                    RootWindow, Sidebar, ChatView, Composer, Settings
                         |
                    @MainActor / @Observable
                         |
Application Layer   AppState, ChatController, ModelController
                    ConversationController, SettingsStore
                         |
              +----------+----------+
              |                     |
Inference Layer              Persistence Layer
LlamaSwiftEngine (actor)    SwiftDataStore (actor)
PromptFormatter              BackupStore
TokenCounter                 MigrationPlan
              |                     |
              +----------+----------+
                         |
Safety Layer        RuntimeProfileProvider, ResourceGuard
                    ContextManager, OutputSanitizer
                    GenerationWatchdog, ModelIntegrity
                         |
                    llama.cpp (pinned SPM)
                    Metal backend + memory-mapped GGUF
```

### Multimodal pipeline

All non-text input is converted to plain text on-device before reaching the model. The model never changes -- Gemma 4 E4B handles everything as text.

| Input | Apple Framework | Output to model |
|---|---|---|
| Image (paste/drag) | Vision (`VNRecognizeTextRequest`, `VNClassifyImageRequest`) | OCR text + scene labels |
| PDF | PDFKit | Extracted page text |
| Word (.docx) / RTF | textutil | Extracted text |
| Markdown / TXT / code | Direct UTF-8 read | Raw text |
| Speech (tap mic to record) | SFSpeechRecognizer (prefers on-device when available) | Transcript |

## Runtime Profiles

Context windows and GPU offload are calibrated per memory class, not computed from formulas. Changes require benchmark approval on reference hardware.

| Memory class | Default context | Max context | Notes |
|---|---:|---:|---|
| 16 -- 23 GB | 8,192 | 8,192 | Supported minimum. Conservative GPU offload. |
| 24 -- 31 GB | 16,384 | 16,384 | Balanced offload. |
| 32 -- 63 GB | 32,768 | 32,768 | Full offload if benchmark-approved. |
| 64 GB+ | 65,536 | 65,536 | 128K is developer-only until proven. |

## Privacy Commitment

Airplane AI does not just promise privacy -- it enforces it at the build system level.

- **Zero network entitlements.** The app ships with `com.apple.security.app-sandbox` and `com.apple.security.device.audio-input` only. No `network.client`, no `network.server`. macOS kernel enforcement means the app physically cannot connect to the internet.
- **Zero telemetry.** No analytics SDKs, no crash reporters, no remote config, no Sparkle updater.
- **CI-verified on every build.** Four verification scripts run as part of the build gate:
  - `verify-entitlements.sh` -- rejects any entitlement not on the allow-list
  - `verify-no-network-symbols.sh` -- scans for `URLSession`, `NWConnection`, `WKWebView`
  - `verify-no-forbidden-deps.sh` -- blocks analytics, telemetry, and crash SDK imports
  - `verify-model-manifest.sh` -- confirms model SHA-256 matches the committed manifest
- **Local-only persistence.** Conversations are stored in SwiftData inside the app sandbox. No iCloud sync. No export in v1.
- **Frozen dependency notices.** Shipped third-party components and exact pinned revisions are listed in [ThirdPartyNotices.txt](Sources/AirplaneAI/Resources/licenses/ThirdPartyNotices.txt).

## Development

```bash
make build       # swift build -c release
make test        # fast test lane (slow suites skipped by default)
make test-slow   # opt-in slow lane: real-model + slow Vision suites
make verify      # run all CI verification scripts
make app         # incremental .app build
make run         # build + launch
make seed        # seed reproducible sample conversations into SwiftData
make screenshots # seed + regenerate product screenshots
make unstick     # clear stale repo/SwiftPM build locks
make bench       # run benchmark suite
make clean       # remove build artifacts
```

First-time setup:

```bash
./scripts/setup-dev.sh
```

### Quality gate

Every change must pass before merging:

```bash
swift build -c release
make test
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-model-manifest.sh
./Tools/ci/verify-no-forbidden-deps.sh
make app
codesign -d --entitlements :- build/AirplaneAI.app
```

## Model

| Field | Value |
|---|---|
| Model | Gemma 4 E4B instruction-tuned |
| Source | [google/gemma-4-E4B-it](https://huggingface.co/google/gemma-4-E4B-it) on Hugging Face |
| Quantization | Q4_K_M |
| Format | GGUF (converted via pinned llama.cpp revision) |
| Size | ~4.5 GB |
| License | Apache 2.0 (Gemma Terms of Use) |
| Capabilities | Text-in / text-out, native system-role support, up to 128K model context |
| Runtime | llama.cpp via Swift Package Manager, pinned by full Git revision SHA |

The model is memory-mapped at runtime (never loaded into a `Data` buffer), verified by incremental SHA-256 on launch, and cached after first verification. A model change is a product change -- it requires a new app version, new benchmarks, and updated release notes.

## Developer tooling

The repo now has two test lanes and deterministic UI helpers:

- `make test` runs the fast default suite.
- `make test-slow` opt-ins the slow real-model and Vision-backed tests.
- `make seed` writes curated sample conversations through the real app/store stack.
- `make screenshots` rebuilds deterministic screenshots into `build/screenshots/`.
- `make unstick` removes stale repo and SwiftPM lock files if a prior build crashed.

## Documentation

| Document | Description |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Build instructions for AI agents -- mindset, developer requirements, execution loop |
| [`briefing/golden-goal.md`](briefing/golden-goal.md) | Full product and engineering specification (v3.0) |
| [`docs/BUILD.md`](docs/BUILD.md) | Detailed build guide and prerequisites |
| [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md) | Release notes for each version |

## License

Airplane AI is proprietary software.

The bundled Gemma 4 E4B model weights are distributed under the [Gemma Terms of Use](https://ai.google.dev/gemma/terms) (Apache 2.0). License files are included in the app bundle at `Sources/AirplaneAI/Resources/licenses/`.

llama.cpp is used under the [MIT License](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE).

---

<p align="center">
  <em>Built for the kind of person who turns off Wi-Fi before opening a notes app.</em>
</p>
