# Airplane AI — Build Instructions for Claude

> **Mission:** Ship **Airplane AI** from zero to a signed, notarized, Mac App Store-ready `.app` **without asking the user questions**. Decide, execute, verify, iterate. TDD-first. No half-built features. No mocks in production code.

## Authority & Sources of Truth

1. **`briefing/golden-goal.md`** — full product + engineering spec (v3.0). This is the contract. If code contradicts it, code is wrong.
2. **This file (`CLAUDE.md`)** — how to execute that spec.
3. **Reference implementation:** **`~/dev/apfel-chat/`** — a working, shipped macOS SwiftPM chat app. **Study it before writing code.** Mirror its layout, Makefile targets, release scripts, test patterns, and Info.plist/entitlements injection via linker flags. It is the canonical example of "how we build Mac apps here."

## Multimodal belongs to Apple (v2 rule — do not violate)

- **Never downgrade the text model to gain multimodal.** Gemma-3n-E4B-it Q4_K_M stays the one and only inference model.
- **Image input** goes through **Apple Vision + VisionKit** on-device:
  - `VNRecognizeTextRequest` for OCR + handwriting
  - `VNClassifyImageRequest` for labels
  - `VNDetectDocumentSegmentationRequest` for doc flag
  - optional `VisionKit.ImageAnalyzer` for natural-language captions
- **Speech input** goes through **`SFSpeechRecognizer`** with `requiresOnDeviceRecognition = true`. Fail hard if the OS says on-device is unavailable; never fall back to the server path.
- **Everything the model sees is plain text.** The Vision / Speech pipelines produce a structured text block that we append to the draft before generation.
- No MLX backend. No llama.cpp mtmd with a second model. No cloud fallback. One inference engine, one model, text-in / text-out. That is the entire contract.
- Entitlements: sandbox + `device.audio-input` only. Nothing else — ever. `Tools/ci/verify-entitlements.sh` enforces this allow-list.
- UI rule: show the user the exact extracted text that will be sent to the model. Honest about what the model actually sees.

## Non-Negotiables (from spec — re-read if you forget)

- One bundled model (Gemma 4 E4B Q4_K_M GGUF), memory-mapped, SHA-256 verified.
- Zero network. Sandbox on. **Only** entitlement: `com.apple.security.app-sandbox`.
- Swift 6 strict concurrency. macOS 15+. Apple Silicon only. 16 GB minimum.
- llama.cpp pinned by **full Git revision SHA** in `Package.swift` (never branch, never floating).
- No telemetry, no analytics, no crash SDKs, no Sparkle, no WebKit, no `URLSession`, no `NWConnection`.
- Never silently truncate the newest user message. Reject with a clear error instead.
- Single window, text-only, no tools, no file access, no import/export in v1.

## The Mindset (read this first, every session)

You are shipping a **consumer product** that a stranger will buy, open on a train, and trust. Not a demo. Not a prototype. Every line of code you write is a promise to that stranger: it will load fast, answer fast, never phone home, never lose their chat, never lie about what it is. If a choice makes the app slower, heavier, less private, or less honest — it is the wrong choice, even if it is easier.

**Think like a craftsman, not a contractor.** Thoughtful beats clever. Simple beats smart. Boring beats novel. Fewer lines, fewer branches, fewer abstractions — but each one load-bearing. If you can delete it, delete it. If you can inline it, inline it. If you cannot test it, redesign it.

**Speed is a feature, not an afterthought.** Cold launch, model load, time-to-first-token, tokens/second, cancellation latency, autosave debounce — measure them, track them, regress-test them. A 200 ms delay the user notices is a bug. Memory-map, not read. Stream, not buffer. Actor-isolate, not lock. Precompute, not recompute. The fastest code is the code that doesn't run.

**Own the outcome.** You are not asking for permission; you are delivering a shipped app. Decide, execute, verify, commit, repeat. When in doubt, re-read `briefing/golden-goal.md` and mirror `~/dev/apfel-chat/`. Then ship.

## Developer Requirements — SUPER CLEAR, NON-NEGOTIABLE

### 1. TDD: Red → Green → Refactor. Always. No exceptions.
- **Red:** Write the failing test **first**. It must fail for the right reason (run it, see red, read the message).
- **Green:** Write the **minimum** code to make it pass. No extras. No speculation. No "while I'm here."
- **Refactor:** Clean up with tests green. Extract, rename, simplify. Re-run tests after every edit.
- **No test, no code.** If you catch yourself writing production code without a failing test behind it — stop, delete, restart from Red.
- **Every protocol has a mock** in `Tests/Mocks/`. Every mock supports cancellation, delays, and injected failures.
- **Golden prompts** with fixed seeds guard prompt formatting, Unicode, code blocks, cancellation, stop reasons.

### 2. Super-Minimal Code — less code = fewer bugs.
- **The fastest, most correct code is code that doesn't exist.** Before writing, ask: can this be deleted, inlined, or replaced with something the stdlib already does?
- **Delete > refactor > add.** Every PR should aim to remove lines as often as add them.
- **No speculative generality.** No framework layers "just in case." No config for things that have one value. No flags for behaviors with one caller.
- **No dead code, no commented-out code, no TODOs, no stubbed "future" branches.** Git remembers; the tree doesn't need to.
- **Prefer value types, pure functions, straight-line code.** Every early return is a deleted `else` branch.
- **If a test needs 50 lines of setup, the code under test is wrong.** Shrink the code, not the test.
- **If you can't explain a function in one sentence, split it.** If you can't name a type in one word, redesign it.
- **Every abstraction costs.** Pay only when you have ≥3 concrete callers and a measured benefit.

### 3. Modular Code — small, single-purpose, composable.
- **≤75 lines per file** (≤150 only for genuinely complex, and justify in a one-line comment at top).
- **≤30 lines per function.** **≤4 parameters.** No boolean parameters — split into two functions.
- **Single responsibility per type.** One reason to change. One thing to test.
- **Named exports only.** No wildcard re-exports. No barrel files that hide dependency direction.
- **Composition > inheritance.** Protocol + struct + injection, not class hierarchies.
- **Dependency rule is absolute:** UI → Application → (Inference | Persistence | Safety) → llama.cpp / SwiftData. Arrows never reverse.

### 4. SSOT — Single Source of Truth, everywhere, always.
- **One model file, one manifest, one SHA, one runtime-profile table** — all in `Resources/` and code, nowhere duplicated.
- **System prompt** lives exactly once: `Resources/prompts/SystemPrompt.txt`. Not hardcoded. Not copy-pasted.
- **Localized strings** live exactly once: `Localizable.xcstrings`. No hardcoded user-visible text anywhere in Swift.
- **Version, build, app name, bundle id** — one source (Info.plist / Package.swift), everything else reads from it.
- **Error messages, stop reasons, memory classes** — enums in `Domain/`, referenced everywhere, duplicated nowhere.
- **DRY to the max.** Three similar lines? Still prefer three lines over a premature abstraction. Three similar *files*? That's a missing abstraction — extract it.
- **If you find yourself editing the same constant/string/config in two places, STOP.** Find the one true home, move it there, delete the duplicate. Always.

### 5. Thoughtful — understand before you type.
- **Read before write.** Open the spec section. Open the analogous apfel-chat file. Then code.
- **Root-cause, not patch.** When something breaks, ask "why" seven times, investigating each answer with evidence before the next question. Fix the cause, not the symptom. Never `--no-verify`, never `try?` to swallow, never silent catch.
- **No magic values.** Every literal earns a named constant with a comment explaining the unit and bound.
- **No TODOs, no commented-out code, no dead code.** Delete it. Git remembers.
- **Comments only explain WHY** (non-obvious constraint, invariant, workaround). Never WHAT (the code says that).
- **Fail fast, fail loud.** No fallbacks, no silent defaults, no half-implemented features. A missing requirement is a hard error at build time if possible, at launch time otherwise.

### 6. Fast — speed is a feature. Measure it. Defend it.
- **Budgets (enforced by benchmarks, regress >10% = blocker):**
  - Cold launch → ready: target fast on 16 GB minimum machine (baseline locked in `Benchmarks/baselines/`).
  - Model verify: incremental SHA-256, cached by `appBuild + manifest + fileMtime+size`. Never re-hash on warm launch.
  - Model load: memory-mapped, warmup prompt, GPU layers per runtime profile.
  - Time-to-first-token: sub-second after warmup on 24 GB class.
  - Tokens/second: tracked per profile, per machine class, in `Benchmarks/baselines/`.
  - Cancellation: ≤150 ms from button press to engine idle.
  - Autosave: debounced ≤500 ms during stream, immediate on completion.
  - UI frame: 60 fps during streaming. No main-thread blocking. No sync I/O from views.
- **Techniques (use by default):**
  - Memory-map models and large read-only assets. Never `Data(contentsOf:)` a multi-GB file.
  - Stream tokens via `AsyncThrowingStream`. Append on MainActor in small batches, not per-token if it costs frames.
  - Actor-isolate state, don't lock. No `DispatchSemaphore`. No `NSLock` in new code.
  - Precompute at build time (manifests, hashes, prompt templates). Don't parse JSON on hot paths.
  - Lazy-init everything expensive. Eager-init only the model on first launch after verification.
  - Batch SwiftData writes. Use background contexts. Never save on every keystroke.
  - `@Observable` for view state. No `ObservableObject` + `@Published` in new code.
- **Rule:** if you add code, run the benchmark suite. If it regresses, you either justify it in writing or revert.

### 7. Honesty — the app never lies, the code never hides.
- UI claims match reality: offline, no accounts, no sync, no telemetry, no tool calls, no file access.
- System prompt reinforces the same. No "I browsed…", no "I checked…", no fake citations.
- Logs stay local. Release builds strip diagnostic logging. Content logging is opt-in and local-only.

### 8. Shipped > Perfect — but shipped means *truly* shipped.
- **Definition of done:** quality gate green + benchmarks within budget + spec §21 release checklist 100% checked + signed + notarized + tagged + committed + pushed.
- **Commit after every green milestone.** Present-tense messages ("Add ResourceGuard memory probe"). Push immediately.
- **Never claim done without evidence.** Paste the passing output. Paste the codesign entitlements dump. Paste the benchmark numbers.

### Execution Loop (follow literally)

1. Re-read the relevant spec section + the analogous apfel-chat file.
2. Write the failing test. Run it. See red.
3. Write the minimum code. Run it. See green.
4. Refactor under green. Keep files ≤75 lines, functions ≤30.
5. Run full quality gate. See all green.
6. Commit with a meaningful message. Push.
7. Update `Benchmarks/baselines/` if performance touched. Diff must be justified.
8. Move to next item. Never leave something half-done.

## Quality Gate (must pass before any "done" claim)

```bash
swift build -c release
swift test
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-model-manifest.sh
./Tools/ci/verify-no-forbidden-deps.sh
make app        # produces build/AirplaneAI.app
codesign -d --entitlements :- build/AirplaneAI.app   # must show ONLY app-sandbox
```

All must exit 0. Forbidden symbols: `URLSession`, `NWConnection`, `WKWebView`, `Sparkle`, any analytics/crash SDK.

## Project Layout (mirror apfel-chat, extend per spec §18)

```
airplane-ai/
├── Package.swift          # pin llama.cpp by full SHA revision
├── Package.resolved       # committed
├── Makefile               # build / test / app / dist / install / release (copy apfel-chat shape)
├── Info.plist             # injected via linker flags (see apfel-chat/Package.swift)
├── AirplaneAI.entitlements # app-sandbox ONLY
├── PrivacyInfo.xcprivacy
├── briefing/golden-goal.md
├── Sources/AirplaneAI/    # App / Domain / Contracts / Inference / Safety / Persistence / UI / Debug / Resources
├── Tests/                 # DomainTests / SafetyTests / PersistenceTests / ChatTests / IntegrationTests / GoldenPromptTests / UITests / Mocks
├── Tools/                 # model pipeline + ci verification scripts
├── Benchmarks/
└── scripts/               # build-app.sh, build-dist.sh, release.sh, notarize.sh (copy & adapt from apfel-chat)
```

## Build Order (strict — do not skip ahead)

Follow spec §19 milestones exactly. Each milestone ends with a green quality gate + a commit:

1. **Foundations** — project skeleton, Package.swift with pinned llama.cpp SHA, domain types, protocols, mocks, CI scripts. Exit: domain+mock tests green.
2. **Model Pipeline** — `Tools/model/{fetch,convert,quantize}.sh`, manifest generator, bundled GGUF + SHA-256. Exit: manifest verifies.
3. **Safety Layer** — RuntimeProfile, ResourceGuard, ContextManager, OutputSanitizer, GenerationWatchdog, LifecycleManager. Exit: safety tests green incl. oversized-message rejection.
4. **Persistence** — SwiftData `AppSchemaV1` + `AppMigrationPlan`, BackupStore, mapper. Exit: round-trip + migration + backup-recovery tests green.
5. **Engine Integration** — `LlamaSwiftEngine` actor, PromptFormatter (use `llama_chat_apply_template` first), token counter, streaming, cancellation, warmup. Exit: tiny-model integration test green.
6. **Application Logic** — ChatController / ModelController / ConversationController, error mapping, title derivation.
7. **UI** — single `Window` (not `WindowGroup`), sidebar+chat+composer (NSTextView wrapper), settings, error sheets, accessibility pass.
8. **Hardening** — soak tests, sleep/wake recovery, benchmarks vs. baselines, forbidden-symbol scan, release checklist (spec §21).

## Key Implementation Anchors

- **Package.swift:** copy apfel-chat's Info.plist linker-flag trick. Add llama.cpp via `.package(url: "https://github.com/ggml-org/llama.cpp", revision: "<full-40-char-sha>")`.
- **Entitlements:** exactly one key, `com.apple.security.app-sandbox = true`. CI script greps for forbidden keys and fails.
- **Concurrency:** `AppState` + controllers `@MainActor`; `LlamaSwiftEngine` is an `actor`; `SwiftDataConversationStore` is an `actor`. No `@unchecked Sendable`.
- **Prompt formatting:** default path = `llama_chat_apply_template()` with the model's `tokenizer.chat_template`. Fallback formatter is single, tested, and only used when metadata is missing.
- **Context fitting:** system prompt + newest user message are inviolable. Trim oldest history. If newest message alone > budget → throw `AppError.inputTooLarge`.
- **Model verification:** incremental SHA-256 (stream, don't load full file). Cache result keyed by `appBuild + manifest + fileMtime+size`. Re-verify when any key changes.
- **Lifecycle:** observe `applicationWillTerminate`, `NSWorkspace.willSleepNotification`, `NSWorkspace.didWakeNotification`. Cancel generation, autosave, unload on terminate/sleep. Mark interrupted assistant messages on relaunch.
- **Logging:** `AIRPLANE_DEBUG` compile flag. Release builds strip diagnostic logs. Never log prompt/response content unless `AIRPLANE_DEBUG_VERBOSE_CONTENT` (local-only, never CI).

## Release

Mirror `~/dev/apfel-chat/scripts/release.sh`. Version via `./scripts/release.sh <x.y.z>`. Notarize via `scripts/notarize.sh`. Mac App Store is the distribution target — no Sparkle.

## When You Get Stuck

- Re-read `briefing/golden-goal.md` §1–3 and §12 (safety invariants).
- Open `~/dev/apfel-chat/` and find the analogous file. Copy its shape, adapt to spec.
- Run the quality gate; the first failing check is the next thing to fix.
- Never downgrade the spec to make a test pass. Fix the code.

## Date & Model

- Session start: state current date (`date +%Y-%m-%d`) and your knowledge cutoff.
- Reporting to user: prefix with `→`. Questions to user: prefix with `⁇`. (But prefer not to ask — just do it.)
