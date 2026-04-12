# Airplane AI

Paid, local-first, text-only macOS chat app. One bundled model (Gemma E4B via pinned llama.cpp). Zero network. Zero telemetry. Sandbox-only.

## Build

```bash
make app
open build/AirplaneAI.app
```

## Test

```bash
swift test
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-model-manifest.sh
./Tools/ci/verify-no-forbidden-deps.sh
```

## Docs

- `CLAUDE.md` — build instructions for AI agents (mindset + developer requirements).
- `briefing/golden-goal.md` — full product + engineering spec (v3.0).

## License

Proprietary. Bundled model license in `Sources/AirplaneAI/Resources/licenses/`.
