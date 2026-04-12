# Airplane AI v0.1.0 — Preview

The first preview of Airplane AI: a paid, local-first, text-only macOS chat app. Bundled Gemma E4B runs entirely on your Mac via llama.cpp. Zero network. Zero telemetry. Sandbox-only.

## What works

- Cold launch → model verify (SHA-256) → load → warm → ready.
- Real streaming tokens via llama.cpp b8763 (`ff5ef82…`).
- Chat, stop, retry, interrupted-message recovery.
- Conversations with search, rename, delete.
- SwiftData persistence + rolling backup snapshots.
- Single entitlement: `com.apple.security.app-sandbox`.
- 46 tests green (domain, safety, persistence, controllers, real-model integration).

## Verified

- `codesign -d --entitlements :- AirplaneAI.app` → only `app-sandbox`.
- `lsof -nP -iTCP -iUDP | grep AirplaneAI` → empty.
- No `URLSession`, `NWConnection`, `WKWebView`, `Sparkle`, or analytics SDKs in `Sources/`.
- GGUF SHA-256 matches bundled manifest on every launch.

## Minimum supported hardware

- Apple Silicon Mac
- macOS 15.0+
- 16 GB unified memory

## Known preview gaps

- Mac App Store submission requires an Xcode project + developer-signed build. The SwiftPM-based `.app` is local-install-ready and notarizable via `scripts/notarize.sh`.
- App Icon is programmatic (SVG → `.icns`) and may be refined.
- Localization ships English-only literals (`L.*`); EN+DE `.xcstrings` is in the tree for future Xcode migration.

## Install

```bash
make app
open build/AirplaneAI.app
```

## License

Proprietary. Bundled Gemma weights under Google's Gemma Terms of Use (see `Sources/AirplaneAI/Resources/licenses/Gemma-Notice.txt`).
