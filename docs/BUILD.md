# Airplane AI — Build Guide

## Prerequisites

| Requirement | Minimum | Check |
|-------------|---------|-------|
| macOS | 15.0+ | `sw_vers -productVersion` |
| Xcode | Full install (not just CommandLineTools) | `xcode-select -p` must point to Xcode.app |
| Architecture | Apple Silicon (arm64) | `uname -m` |
| RAM | 16 GB unified memory | `sysctl hw.memsize` |
| Swift | 6.0+ | `swift --version` |

**Why full Xcode?** SwiftData's `@Model` macro uses `SwiftDataMacros` compiler plugin, which ships only in the Xcode toolchain — not in the standalone CommandLineTools.

## Quick Start

```bash
# One-command setup (verifies prereqs, patches paths, builds, tests, verifies):
./scripts/setup-dev.sh

# Or step by step:
make build      # swift build -c release
make test       # swift test --parallel
make verify     # run all CI verification scripts
make app        # build AirplaneAI.app bundle
make run        # build + launch
```

## Machine-Specific Setup

The `Package.swift` dev rpath points to the vendored llama.cpp dylibs using an absolute path. When cloning on a new machine, this path must match:

```
Vendor/llama.cpp/llama-b8763/
```

The `setup-dev.sh` script patches this automatically. To do it manually:

```bash
# In Package.swift, find the dev rpath line and update to your checkout:
"-Xlinker", "/Users/<you>/dev/airplane-ai/Vendor/llama.cpp/llama-b8763",
```

## Xcode Toolchain Switch

If `xcode-select -p` returns `/Library/Developer/CommandLineTools`, switch:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Build Targets

| Target | Command | Output |
|--------|---------|--------|
| Release binary | `make build` | `.build/release/AirplaneAI` |
| Test suite | `make test` | test results |
| App bundle | `make app` | `build/AirplaneAI.app` |
| Distribution zip | `make dist` | `dist/AirplaneAI-<ver>.zip` |
| Full release | `make release` | tagged + notarized + GitHub release |
| CI verification | `make verify` | entitlements, symbols, deps, manifest |
| Benchmarks | `make bench` | performance baselines |
| Clean | `make clean` | removes .build, build, dist |

## Verification Scripts

All must pass before any "done" claim:

```bash
./Tools/ci/verify-entitlements.sh       # only app-sandbox allowed
./Tools/ci/verify-no-network-symbols.sh # no URLSession, NWConnection, etc.
./Tools/ci/verify-no-forbidden-deps.sh  # only llama.cpp in Package.resolved
./Tools/ci/verify-model-manifest.sh     # GGUF SHA-256 matches manifest
```

## Architecture

```
Package.swift          # SwiftPM manifest, vendored llama.cpp via dylibs
Vendor/llama.cpp/      # Pre-built dylibs (libllama, libggml-*)
Sources/CLlama/        # C shim: headers + modulemap for llama.cpp
Sources/AirplaneAI/    # Main app (Domain, Contracts, Inference, Safety, Persistence, UI)
Tests/                 # Full test suite
Tools/ci/              # CI verification scripts
scripts/               # build-app.sh, build-dist.sh, release.sh, notarize.sh, setup-dev.sh
```

The app uses vendored llama.cpp dylibs (not SPM source dependency) from `Vendor/llama.cpp/llama-b8763/`. These get embedded into `AirplaneAI.app/Contents/Frameworks/` by `scripts/build-app.sh`.

## Code Signing

Ad-hoc by default. For distribution:

```bash
SIGN_IDENTITY="Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)" make app
```

Notarization: `./scripts/notarize.sh`
