I found and corrected the biggest structural faults before rewriting it:

* The original spec claimed Gemma 4 E4B on an 8 GB Mac was a supported minimum target. Google’s published guidance puts Gemma 4 E4B around **5 GB just to load at Q4_0**, before KV cache, prompt buffers, app memory, and macOS headroom, so an 8 GB “supported minimum” is not a production-grade promise for this model. The rewritten spec makes **16 GB unified memory the supported minimum** for the E4B release. ([Google AI for Developers][1])
* The original dependency pin was invalidly expressed as `exact: "b8680"`. Apple’s Swift package docs distinguish **exact versions** from **source-control revisions**, and package versions are expected to follow semantic versioning. The rewritten spec pins llama.cpp by **full Git revision**. ([Apple Developer][2])
* The original spec blurred **model capability** and **app-supported defaults**. Gemma 4 E4B supports a 128K model context and native system-role prompting, but that does not mean a consumer macOS app should expose or promise 128K on all hardware classes. The rewritten spec separates those clearly. ([Google AI for Developers][1])
* The original spec treated a bundled multi-GB model as a packaging concern. Apple’s current limit for macOS apps is **200 GB uncompressed**, so bundling one large model is fine; the real issue is runtime memory and user experience, not App Store size limits. ([Apple Developer][3])
* The original spec said “no network” but did not ground it rigorously enough. Apple documents App Sandbox as kernel-enforced, and `com.apple.security.network.client` as the entitlement for outgoing network connections. The rewrite makes zero-network a hard build/runtime rule, not just a slogan. ([Apple Developer][4])
* The original spec delayed storage hardening. The rewrite requires **versioned SwiftData schemas and a migration plan from v1**, plus local backup snapshots inside the sandbox. ([Apple Developer][5])

# Airplane AI — Engineering Specification v3.0

> **Audience:** Coding AIs, human engineers, and future maintainers.
> **Authority:** This document is the source of truth for v1.0. If code, comments, or conversations contradict this document, this document wins.
> **Release philosophy:** Airplane AI is a consumer app, not a demo. Reliability, privacy, and clarity outrank feature count.

---

## 1. Product Definition

Airplane AI is a paid, local-first, text-only macOS chat app. It ships exactly one bundled model: **Gemma 4 E4B instruction-tuned**, converted from official Google weights into GGUF as part of a pinned and reproducible release pipeline. Google documents Gemma 4 as Apache 2.0 licensed, available from Hugging Face and Kaggle, with native system-role support; E2B/E4B expose up to 128K model context, and Google lists llama.cpp among its local/edge runtime paths. Airplane AI intentionally uses **text-only chat** in v1 even though the underlying model family supports more modalities. ([Google AI for Developers][6])

Apple requires App Sandbox for Mac App Store distribution, documents the sandbox as kernel-enforced, and documents `com.apple.security.network.client` as the entitlement that allows outgoing network connections. Airplane AI ships with App Sandbox enabled and **no network entitlements at all**. ([Apple Developer][4])

### Product properties

* **Name:** Airplane AI
* **Platform:** macOS 15.0+
* **Hardware:** Apple Silicon only
* **Supported minimum hardware:** 16 GB unified memory
* **Unsupported hardware:** 8 GB Macs for the E4B release
* **Distribution:** Mac App Store
* **Business model:** paid app, one-time purchase, no IAP, no subscriptions
* **Model:** Gemma 4 E4B instruction-tuned, shipped as one bundled GGUF
* **Inference runtime:** llama.cpp, pinned to a specific source revision
* **Language:** Swift 6 mode with strict concurrency
* **UI:** SwiftUI, with AppKit wrappers only where SwiftUI is insufficient
* **Persistence:** SwiftData with versioned schemas and migration plan
* **Networking:** none
* **Telemetry:** none
* **Analytics / crash reporting / remote config:** none

### What this app is

* A private, offline chat app for writing, thinking, coding, brainstorming, and general text assistance
* A single-window desktop app
* A single-model product with one carefully tuned runtime profile table
* A text-only interface with local conversation history

### What this app is not

* Not free, not freemium, not subscription
* Not a model switcher
* Not an IDE
* Not an agent framework
* Not a plugin host
* Not a tool-calling system
* Not a browser
* Not a file/chat-with-documents app in v1
* Not voice, image, or video input in v1
* Not multiwindow in v1
* Not iCloud-synced
* Not import/export capable in v1, because v1 keeps file-access entitlements at zero
* Not connected to the internet in any way at runtime

---

## 2. Non-Negotiable Product Invariants

These are hard rules.

1. **One bundled model only.**
   One source model, one quantization, one conversion recipe, one shipped GGUF, one hash.

2. **No runtime downloads.**
   No model downloads, no “check for updates,” no remote prompt updates, no remote blocklists, no CDN assets, no hosted embeddings, no hidden background assets.

3. **Zero network at runtime.**
   No `network.client`, no `network.server`, no `URLSession`, no `NWConnection`, no web views, no analytics SDKs, no crash SDKs.

4. **Consumer-first UX.**
   No raw sampling sliders in the release UI. Advanced knobs exist only in debug builds.

5. **One active generation at a time.**
   No hidden queue. No parallel generations. If the user interrupts generation, the app cancels cleanly.

6. **Never silently truncate the user’s current message.**
   Old history may be dropped to fit context. The newest user message may not. If it is too large, sending fails with a clear error.

7. **The app must never claim capabilities it does not have.**
   The system prompt and UI copy must reinforce that the assistant has no internet, no tools, no file access outside the chat text, and no knowledge of current events beyond its offline weights.

8. **A model change is a product change.**
   Any change to the model file, conversion recipe, quantization, tokenizer metadata, or pinned llama.cpp revision requires a new app version, new benchmarks, new hash, and updated release notes.

---

## 3. Supported Runtime Envelope

The original v2.0 spec tried to support Gemma 4 E4B on 8 GB Macs. That is no longer acceptable. Google’s published estimate is roughly **5 GB to load E4B at Q4_0** before app overhead and context growth. That published number alone is enough to show that 8 GB is too tight for a consumer-quality promise on E4B. That conclusion is our engineering judgment based on Google’s published memory table, not a claim that Q4_K_M has the exact same footprint. ([Google AI for Developers][1])

### Support matrix

| Memory class | Support status    | Default context | Max release context | Notes                                     |
| ------------ | ----------------- | --------------: | ------------------: | ----------------------------------------- |
| 8–15 GB      | Unsupported       |               — |                   — | E4B build does not promise stability here |
| 16–23 GB     | Supported minimum |           8,192 |               8,192 | Conservative GPU offload                  |
| 24–31 GB     | Supported         |          16,384 |              16,384 | Balanced                                  |
| 32–63 GB     | Supported         |          32,768 |              32,768 | Full offload if benchmark-approved        |
| 64 GB+       | Supported         |          65,536 |              65,536 | 128K is developer-only until proven       |

### Runtime profile rule

Runtime tuning is not derived from hand-wavy formulas. It is stored in code as a **versioned runtime profile table** and changed only after benchmark approval on reference hardware.

```swift
struct RuntimeProfile: Sendable, Equatable {
    let memoryClass: MemoryClass
    let defaultContext: Int
    let maxSupportedContext: Int
    let gpuLayerPolicy: GPULayerPolicy
    let batchSize: Int
    let ubatchSize: Int
    let flashAttention: FlashAttentionPolicy
    let warmupEnabled: Bool
}
```

### Release policy

* The **supported minimum device** for v1.0 is an Apple Silicon Mac with **16 GB unified memory**
* 8 GB devices may exist in internal experiments, but they are **not** part of the release acceptance bar
* If 8 GB support ever becomes a hard business requirement, the only acceptable fix is a **spec change**, likely by switching the sole model to a smaller tier

---

## 4. Model Strategy and Provenance

Gemma 4 E4B is the product model. Google publishes Gemma 4 weights through official channels and documents native system-role prompting, 128K context for E2B/E4B, and llama.cpp as a supported edge runtime path. Airplane AI uses that official model family but ships its own pinned GGUF artifact. ([Google AI for Developers][1])

### Required provenance artifacts

Every release must include:

* official source model ID
* official source revision or snapshot
* conversion tool revision
* quantization recipe
* final GGUF SHA-256
* bundled license files and notices
* machine-readable manifest checked into the repo

### Shipped manifest

```json
{
  "source_model_id": "google/gemma-4-E4B-it",
  "source_channel": "Hugging Face",
  "source_revision": "<source snapshot or commit>",
  "conversion_runtime_revision": "<llama.cpp git sha>",
  "quantization": "Q4_K_M",
  "gguf_sha256": "<sha256>",
  "model_capability_context": 131072,
  "app_default_context": 8192,
  "license": "Apache-2.0"
}
```

### Model packaging rules

* The GGUF is bundled inside the app
* The GGUF is read-only
* The GGUF is memory-mapped
* The app does not download or mutate model weights at runtime
* The model manifest is bundled alongside the GGUF
* The app includes the Gemma license and notices in an About / Licenses view

### Explicit scope cut

Although Gemma 4 E4B supports audio and broader multimodal input, Airplane AI v1 is **text-only**. No microphone, no image picker, no drag-and-drop attachments, no video, no tool calling. ([Google AI for Developers][1])

---

## 5. Dependency and Build Policy

The original v2.0 spec used `exact: "b8680"`, which is the wrong concept for a commit-style pin. Apple distinguishes exact version requirements from source-control revisions, and Swift package versions follow semantic versioning. Airplane AI therefore pins llama.cpp by **full revision SHA**, not by branch and not by informal tag names. ([Apple Developer][2])

### Rule

* Never track `main`
* Never track a branch
* Never use floating version ranges
* Commit `Package.resolved`
* Pin by full Git revision unless upstream publishes a real version we intentionally adopt

### Example

```swift
dependencies: [
    .package(
        url: "https://github.com/ggml-org/llama.cpp",
        revision: "0123456789abcdef0123456789abcdef01234567"
    )
]
```

### Update policy

A llama.cpp update is allowed only if all of the following happen:

1. benchmark suite passes on all reference machines
2. golden-prompt regression suite passes
3. no user-facing quality regressions are observed
4. no performance metric regresses by more than 10% without explicit approval
5. model conversion pipeline is re-run and the new GGUF hash is recorded

### Prompt formatting rule

By default, prompt formatting uses the model’s own chat-template metadata through `llama_chat_apply_template()`. llama.cpp documents that this function uses the template stored in `tokenizer.chat_template` by default, which is exactly what we want. Airplane AI only falls back to a custom formatter if metadata is missing or incompatible. This pairs well with Google’s documented native system-role support in Gemma 4. ([GitHub][7])

---

## 6. System Prompt and Prompt Formatting

The exact system prompt lives in `Resources/SystemPrompt.txt` and is regression-tested. It is not hardcoded across multiple files.

### System prompt goals

The assistant must:

* state or imply that it is local and offline
* never claim to browse, check live facts, open apps, or use tools
* never claim access to files beyond chat text the user has typed or pasted
* answer honestly when it does not know
* avoid pretending to remember anything outside the current conversation
* be concise, helpful, and calm
* default to Markdown-safe plain text
* never invent citations, sources, or links

### Prompt formatting rules

* Use native system role where supported
* Use model metadata template first
* Use a single tested fallback formatter only if metadata is unavailable
* Never maintain multiple competing prompt formats in production
* Any prompt-format change requires golden-prompt reapproval

---

## 7. Architecture

```text
┌────────────────────────────────────────────────────────────┐
│                        Airplane AI.app                     │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                       UI Layer                       │  │
│  │  RootWindow ─ Sidebar ─ ChatView ─ Composer         │  │
│  │  StatusBar ─ Settings ─ ErrorSheets                 │  │
│  └───────────────────────┬──────────────────────────────┘  │
│                          │ @MainActor / @Observable        │
│  ┌───────────────────────▼──────────────────────────────┐  │
│  │                   Application Layer                   │  │
│  │  AppState ─ ChatController ─ ConversationController │  │
│  │  ModelController ─ SettingsStore                    │  │
│  └──────────────┬───────────────────────┬──────────────┘  │
│                 │                       │                 │
│  ┌──────────────▼─────────────┐  ┌──────▼──────────────┐  │
│  │        Inference Layer      │  │    Persistence     │  │
│  │  LlamaSwiftEngine (actor)   │  │ SwiftDataStore     │  │
│  │  PromptFormatter            │  │ BackupStore        │  │
│  │  TokenCounter               │  │ MigrationPlan      │  │
│  └──────────────┬─────────────┘  └──────┬──────────────┘  │
│                 │                       │                 │
│  ┌──────────────▼───────────────────────▼──────────────┐  │
│  │                    Safety Layer                      │  │
│  │ RuntimeProfileProvider  ResourceGuard               │  │
│  │ ContextManager         OutputSanitizer              │  │
│  │ GenerationWatchdog     ModelIntegrity               │  │
│  │ LifecycleManager       CrashRecovery                │  │
│  └──────────────────────────┬──────────────────────────┘  │
│                             │                              │
│  ┌──────────────────────────▼──────────────────────────┐  │
│  │               llama.cpp via pinned SPM              │  │
│  │           Metal backend + memory-mapped GGUF        │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │          Bundled resources: model, manifest,         │  │
│  │           licenses, strings, icons, prompts          │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Dependency rule

Dependencies flow downward only.

* UI → Application
* Application → Inference / Persistence / Safety
* Inference → llama.cpp
* Persistence → SwiftData
* Safety may be used by Application and Inference
* Nothing below the UI layer imports SwiftUI
* Nothing outside the engine touches raw llama.cpp types

### Process rule

One process only in v1.

* no helper tools
* no XPC services
* no login items
* no menu bar extra
* no background daemon

---

## 8. State Machines

### 8.1 Model lifecycle

```text
cold
  → verifyingModel
  → loadingModel
  → warmingModel
  → ready
  → unloading
  → cold
```

Error substates:

```text
blockedInsufficientResources
modelMissing
modelCorrupt
loadFailed
migrationFailed
```

### 8.2 Chat lifecycle

```text
idle
  → generating
  → cancelling
  → idle
```

Rules:

* one active generation per app
* pressing Send while idle starts generation
* pressing Stop while generating cancels generation
* switching conversations while generating cancels generation first
* there is no silent queue of pending user prompts
* if generation is interrupted by sleep or quit, the partial message is kept and marked as interrupted

---

## 9. Concurrency Model

Swift 6 strict concurrency. No data races. No casual `@unchecked Sendable`.

### Isolation plan

* `AppState` and UI-facing controllers are `@MainActor`
* `LlamaSwiftEngine` is an `actor`
* `SwiftDataConversationStore` is an `actor` owning its persistence context
* long-running tasks are owned through explicit `Task` handles
* cancellation is structured and propagated

### Rules

* avoid detached tasks by default
* no long-running work on the main actor
* no blocking C calls from the UI layer
* never let multiple tasks mutate conversation state concurrently
* all streamed token appends happen on the main actor after crossing the engine boundary

---

## 10. Protocols and Core Contracts

```swift
enum StopReason: String, Sendable, Codable {
    case completed
    case cancelledByUser
    case contextLimitReached
    case repetitiveOutput
    case whitespaceRun
    case outputTooLong
    case stalled
    case lowMemory
    case lowDisk
    case interruptedByLifecycle
    case engineError
}

enum AppError: LocalizedError, Sendable, Equatable {
    case insufficientMemory(requiredGB: Double, availableGB: Double)
    case insufficientDisk(requiredGB: Double, availableGB: Double)
    case modelMissing
    case modelCorrupt
    case modelVerificationFailed
    case inputTooLarge(maxTokens: Int)
    case modelLoadFailed(summary: String)
    case generationFailed(summary: String)
    case persistenceFailed(summary: String)
    case migrationFailed
}

struct TokenChunk: Sendable, Equatable {
    let text: String
    let tokenID: Int32?
    let index: Int
    let tokensPerSecond: Double?
}

enum StreamEvent: Sendable, Equatable {
    case token(TokenChunk)
    case finished(StopReason)
}

protocol InferenceEngine: Sendable {
    func loadModel(at path: URL, profile: RuntimeProfile) async throws
    func unloadModel() async
    var isModelLoaded: Bool { get async }
    var loadedModelInfo: ModelInfo? { get async }

    func generate(
        messages: [ChatMessage],
        parameters: GenerationParameters,
        contextManager: ContextManager
    ) -> AsyncThrowingStream<StreamEvent, Error>

    func cancelGeneration() async
    func countTokens(in text: String) async throws -> Int
}

protocol TokenCounter: Sendable {
    func countTokens(in text: String) async throws -> Int
}

protocol ConversationStore: Sendable {
    func allConversations() async throws -> [Conversation]
    func conversation(id: UUID) async throws -> Conversation?
    func save(_ conversation: Conversation) async throws
    func delete(id: UUID) async throws
    func saveBackupSnapshot(_ conversations: [Conversation]) async throws
    func loadLatestBackupSnapshot() async throws -> [Conversation]?
}
```

### Contract rules

* The engine owns all llama.cpp state
* The UI never sees raw C pointers
* The store persists domain data, not UI view state
* Every protocol has at least one test double
* Mocks must support cancellation, delays, and injected failures

---

## 11. Domain Model

```swift
struct Conversation: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String = "New Chat") {
        self.id = id
        self.title = title
        self.messages = []
        self.createdAt = .now
        self.updatedAt = .now
    }
}

enum MessageRole: String, Codable, Sendable {
    case system
    case user
    case assistant
}

enum MessageStatus: String, Codable, Sendable {
    case complete
    case streaming
    case interrupted
    case failed
}

struct ChatMessage: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let createdAt: Date
    var status: MessageStatus
    var stopReason: StopReason?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        createdAt: Date = .now,
        status: MessageStatus = .complete,
        stopReason: StopReason? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.status = status
        self.stopReason = stopReason
    }
}

struct ModelInfo: Codable, Sendable, Equatable {
    let name: String
    let sizeBytes: Int64
    let sha256: String
    let contextWindow: Int
}

struct GenerationParameters: Codable, Sendable, Equatable {
    var temperature: Float = 0.6
    var topP: Float = 0.95
    var topK: Int = 40
    var maxTokens: Int = 1024
    var repeatPenalty: Float = 1.1
    var seed: Int32 = -1  // -1 = random in release, fixed in tests

    func clamped() -> GenerationParameters {
        var p = self
        if !p.temperature.isFinite { p.temperature = 0.6 }
        if !p.topP.isFinite { p.topP = 0.95 }
        if !p.repeatPenalty.isFinite { p.repeatPenalty = 1.1 }

        p.temperature = max(0.0, min(1.5, p.temperature))
        p.topP = max(0.01, min(1.0, p.topP))
        p.topK = max(1, min(200, p.topK))
        p.maxTokens = max(1, min(4096, p.maxTokens))
        p.repeatPenalty = max(1.0, min(2.0, p.repeatPenalty))
        return p
    }
}
```

### Public parameter policy

Release builds do **not** expose raw `GenerationParameters` controls in Settings. Those remain fixed defaults. Debug builds may expose them behind a developer-only panel.

### Title policy

Conversation titles are not AI-generated in v1.
They are derived from the first user message and may be manually renamed.

---

## 12. Safety Systems

This section is mandatory. These systems exist to prevent system damage, data loss, bad UX, and unbounded complexity.

### 12.1 RuntimeProfileProvider

`RuntimeProfileProvider` determines the active profile based on hardware and approved tuning data.

Rules:

* keyed primarily by memory class
* chip generation is a secondary hint, not the primary key
* no magic “99 means all layers”
* use an explicit `GPULayerPolicy`

```swift
enum GPULayerPolicy: Sendable, Equatable {
    case none
    case fixed(Int)
    case all
}
```

### 12.2 ResourceGuard

The original spec only guarded free memory. v3.0 guards **memory and disk**.

Responsibilities:

* check preconditions before model verification and model load
* check memory pressure during generation
* check disk free space to avoid swap death spirals
* stop generation gracefully before system-level distress
* surface user-facing errors early

Rules:

* resource checks happen before hash verification, before model load, before generation, and periodically during generation
* resource thresholds come from the active runtime profile table
* if memory becomes unsafe during generation, stop and persist the partial answer
* if disk free space is dangerously low, block model load

### 12.3 ContextManager

The original spec allowed truncating a single oversized user message. v3.0 forbids that.

Rules:

* always include the system prompt
* always include the most recent user message in full
* trim oldest history first
* never silently alter the user’s current message
* if the newest user message alone exceeds the allowed input budget, reject send with a clear message

```swift
struct ContextManager: Sendable {
    let maxContextTokens: Int
    let reservedForResponse: Int
    let templateOverheadTokens: Int

    func fitToContext(
        messages: [ChatMessage],
        tokenCounter: TokenCounter
    ) async throws -> [ChatMessage]
}
```

### 12.4 OutputSanitizer

The original sanitizer only watched repeated strings and whitespace. v3.0 also tracks token IDs and invalid output patterns.

Rules:

* stop on excessive repeated token IDs
* stop on excessive repeated lines
* stop on whitespace-only runs
* stop at max output token count
* normalize or reject invalid Unicode
* return an explicit stop reason

### 12.5 GenerationWatchdog

A local model can stall without technically crashing.

Rules:

* enforce a maximum time-to-first-token threshold by runtime profile
* enforce a maximum silent gap after generation starts
* allow user cancellation at all times
* mark stalled outputs as interrupted, not complete

### 12.6 ModelIntegrity

Hash verification is required, but it should not punish every launch.

Rules:

* verify the bundled model on first launch after install or app update
* cache a successful result keyed by app build + bundled manifest + model file metadata
* reverify when the app build changes or the model metadata changes
* hash the file incrementally; never load the full file into memory for hashing
* if verification fails, block inference and show a recovery screen

### 12.7 LifecycleManager and CrashRecovery

The original spec used an iOS-style background callback. v3.0 uses real macOS lifecycle events.

Observe:

* `applicationWillTerminate`
* `NSWorkspace.willSleepNotification`
* `NSWorkspace.didWakeNotification`

Rules:

* on terminate or sleep: cancel generation, autosave, unload model
* on next launch: unfinished assistant messages are marked `interrupted`
* shutdown recovery is best-effort, not magical; the app must still autosave during normal use

---

## 13. Persistence, Migration, and Local Backup

SwiftData supports versioned schemas and migration plans through `VersionedSchema`, `SchemaMigrationPlan`, and explicit migration stages. Airplane AI uses those from v1.0, not “later when we need it.” ([Apple Developer][5])

### Storage rules

* Domain types remain framework-free Swift structs
* SwiftData model classes live only in the persistence layer
* Mapping between domain and persistence is explicit
* The persistent store lives only in the app sandbox
* The app keeps rolling local backup snapshots in its own sandbox container

### Autosave policy

* save on new conversation creation
* save on each completed assistant response
* debounce saves during streaming, at most every 500 ms
* save on cancel
* save on sleep
* save on terminate

### Backup policy

* after each completed response, write a sandbox-local JSON snapshot
* keep the last 10 snapshots
* snapshots are local only and never exported automatically
* on store corruption or migration failure, attempt recovery from the latest snapshot

### Migration policy

* `AppSchemaV1` exists from the first shipping build
* every future store change increments schema version
* every migration path is tested with real fixture stores
* migration failure blocks normal use and presents a reset/recover flow

### No import/export in v1

Because v1 intentionally keeps file-access entitlements at zero, there is no user-visible import/export flow in the first release. Data portability is handled later only if the entitlement posture changes by spec.

---

## 14. UI and UX Requirements

### Windowing

* single-window app in v1
* use `Window`, not `WindowGroup`, to avoid multiwindow complexity
* one sidebar + one detail pane

### Main layout

* sidebar: conversation list
* detail: active chat
* footer/status strip: model state
* settings sheet
* error sheets for model corruption, insufficient resources, migration failure

### Composer

* implemented with a custom `NSTextView` wrapper, not a plain `TextField`
* Enter sends
* Shift+Enter inserts newline
* Send becomes Stop during generation
* the app never queues multiple sends invisibly

### Conversation behavior

* auto-scroll during streaming unless the user has manually scrolled away
* interrupted assistant messages are visibly marked
* retry uses the same user message, not regenerated history
* long-conversation trimming is surfaced gently in the UI

### Markdown rendering

Supported in v1:

* paragraphs
* emphasis
* inline code
* fenced code blocks
* bullet/numbered lists

Not supported in v1:

* raw HTML
* remote images
* embedded web content
* clickable external links by default

Links may be rendered as selectable text, but the app does not auto-open them.

### Settings

Release settings include:

* appearance
* language
* clear all conversations
* privacy/about
* version/build info

Debug-only settings include:

* runtime profile override
* sampling controls
* benchmark overlay
* verbose logging toggle

### Accessibility

Required for v1:

* VoiceOver labels on all controls
* full keyboard navigation
* sufficient contrast
* reduced-motion support
* focus-safe cancellation and retry actions
* copyable code blocks and message text

---

## 15. Security and Privacy

Apple requires App Sandbox for Mac App Store apps, documents the sandbox as kernel-enforced, and documents `com.apple.security.network.client` as the outgoing network entitlement. Airplane AI keeps the entitlement profile intentionally minimal: sandbox enabled, no network entitlements, no file entitlements, no device entitlements, no personal-data entitlements. ([Apple Developer][4])

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>
</plist>
```

### Forbidden capabilities

* no `com.apple.security.network.client`
* no `com.apple.security.network.server`
* no user-selected file entitlements
* no camera, microphone, Bluetooth, USB, contacts, calendar, photos, location
* no WebKit
* no analytics SDKs
* no crash-reporting SDKs
* no Sparkle
* no remote config
* no model downloads

### Static and dynamic enforcement

CI must fail if any of these are true:

* entitlements file contains forbidden keys
* linked frameworks include obvious network or web surfaces not explicitly approved
* source introduces banned APIs such as `NWConnection`, `URLSession`, or `WKWebView`
* third-party SDKs appear in the dependency graph

Release verification must also include:

* `codesign -d --entitlements :- AirplaneAI.app`
* `lsof -i -P | grep AirplaneAI`
* local firewall or monitor verification showing zero connection attempts during use

### Privacy truthfulness

All user-facing claims must match reality:

* on-device only
* no accounts
* no cloud sync
* no telemetry
* no remote moderation
* no hidden uploads

---

## 16. Logging and Diagnostics

### Compile flags

* `AIRPLANE_DEBUG`
* `AIRPLANE_DEBUG_VERBOSE_CONTENT` — local-only, never CI, never release

### Logging rules

* release builds compile diagnostic logging out
* normal debug logs never include full user prompts or assistant responses
* content logging is opt-in and local-only
* logs capture timings, state transitions, hashes, counts, errors, and profile IDs
* all logs stay on-device

### Diagnostic categories

* inference
* memory
* storage
* lifecycle
* safety
* ui
* migration

### Performance logging

Capture:

* model verification time
* model load time
* warmup time
* time to first token
* average tok/s
* peak memory
* cancellation latency
* autosave latency

---

## 17. Testing and Benchmarking

### Development rule

Red → Green → Refactor.

### Test categories

| Category           | Scope                                                | Real model required | Runs in CI |
| ------------------ | ---------------------------------------------------- | ------------------: | ---------: |
| DomainTests        | value types, clamping, title derivation              |                  No |        Yes |
| SafetyTests        | context fitting, sanitizer, watchdog, resource guard |                  No |        Yes |
| PersistenceTests   | SwiftData mapping, migration, backup recovery        |                  No |        Yes |
| ChatTests          | controller behavior with mock engine                 |                  No |        Yes |
| UITests            | end-to-end flows with mock engine                    |                  No |        Yes |
| IntegrationTests   | tiny test model load/generate                        |          Small only |        Yes |
| GoldenPromptTests  | deterministic prompt formatting / smoke outputs      |        Tiny or mock |        Yes |
| HardwareBenchmarks | real E4B, real machines                              |                 Yes |         No |

### Required fixtures

* old store fixture for every schema version
* corrupt store fixture
* corrupt model manifest fixture
* missing model fixture
* giant user message fixture
* interrupted-stream recovery fixture

### Golden prompt suite

Maintain a small set of pinned prompts with fixed seeds and strict expectations for:

* prompt formatting
* system-role handling
* Unicode
* code blocks
* cancellation
* stop reasons

### Benchmark suite

Track at minimum:

* cold launch to ready
* model verification time
* model load time
* TTFT
* tok/s
* peak RSS
* peak compressed memory
* peak disk pressure / swap behavior
* cancellation latency
* 30-minute idle memory stability
* 60-minute soak memory stability

### Benchmark policy

* benchmark on the minimum supported machine and one high-end reference machine
* do not update llama.cpp or the model bundle if any accepted metric regresses by more than 10% without explicit approval
* record every accepted benchmark set in versioned files, not only in prose

---

## 18. Project Structure

```text
AirplaneAI/
├── AirplaneAI.xcodeproj/
├── Package.swift
├── Package.resolved
│
├── Sources/
│   └── AirplaneAI/
│       ├── App/
│       │   ├── AirplaneAIApp.swift
│       │   ├── AppState.swift
│       │   ├── ChatController.swift
│       │   ├── ConversationController.swift
│       │   └── ModelController.swift
│       │
│       ├── Domain/
│       │   ├── Conversation.swift
│       │   ├── ChatMessage.swift
│       │   ├── GenerationParameters.swift
│       │   ├── ModelInfo.swift
│       │   └── StopReason.swift
│       │
│       ├── Contracts/
│       │   ├── InferenceEngine.swift
│       │   ├── TokenCounter.swift
│       │   └── ConversationStore.swift
│       │
│       ├── Inference/
│       │   ├── LlamaSwiftEngine.swift
│       │   ├── PromptFormatter.swift
│       │   ├── LlamaTokenCounter.swift
│       │   └── ModelLocator.swift
│       │
│       ├── Safety/
│       │   ├── RuntimeProfile.swift
│       │   ├── RuntimeProfileProvider.swift
│       │   ├── ResourceGuard.swift
│       │   ├── ContextManager.swift
│       │   ├── OutputSanitizer.swift
│       │   ├── GenerationWatchdog.swift
│       │   ├── ModelIntegrity.swift
│       │   ├── LifecycleManager.swift
│       │   └── CrashRecovery.swift
│       │
│       ├── Persistence/
│       │   ├── SwiftDataConversationStore.swift
│       │   ├── BackupStore.swift
│       │   ├── StoreMapper.swift
│       │   ├── Schema/
│       │   │   ├── AppSchemaV1.swift
│       │   │   ├── AppMigrationPlan.swift
│       │   │   ├── StoredConversation.swift
│       │   │   └── StoredMessage.swift
│       │
│       ├── UI/
│       │   ├── RootWindow.swift
│       │   ├── ConversationListView.swift
│       │   ├── ChatView.swift
│       │   ├── MessageBubble.swift
│       │   ├── ComposerView.swift
│       │   ├── StatusBarView.swift
│       │   ├── SettingsView.swift
│       │   ├── ErrorViews/
│       │   │   ├── InsufficientResourcesView.swift
│       │   │   ├── ModelCorruptView.swift
│       │   │   └── MigrationFailureView.swift
│       │   └── MarkdownText.swift
│       │
│       ├── Debug/
│       │   └── AirLog.swift
│       │
│       └── Resources/
│           ├── models/
│           │   ├── airplane-model.gguf
│           │   └── airplane-model-manifest.json
│           ├── prompts/
│           │   └── SystemPrompt.txt
│           ├── licenses/
│           │   └── Gemma-Apache-2.0.txt
│           ├── Assets.xcassets/
│           └── Localizable.xcstrings
│
├── Tools/
│   ├── model/
│   │   ├── fetch-model.sh
│   │   ├── convert-to-gguf.sh
│   │   ├── quantize-model.sh
│   │   └── generate-manifest.py
│   └── ci/
│       ├── verify-entitlements.sh
│       ├── verify-no-network-symbols.sh
│       ├── verify-model-manifest.sh
│       └── verify-no-forbidden-deps.sh
│
├── Benchmarks/
│   ├── prompts/
│   ├── baselines/
│   └── run-benchmarks.swift
│
├── Mocks/
│   ├── MockInferenceEngine.swift
│   ├── MockConversationStore.swift
│   └── MockTokenCounter.swift
│
└── Tests/
    ├── DomainTests/
    ├── SafetyTests/
    ├── PersistenceTests/
    ├── ChatTests/
    ├── IntegrationTests/
    ├── GoldenPromptTests/
    └── UITests/
```

---

## 19. Implementation Order

### Milestone 1 — Foundations

* create project
* set entitlements
* add pinned llama.cpp dependency
* define domain models and protocols
* add debug logging shell
* create mocks
* get CI green

**Exit bar:** all domain and mock tests pass

### Milestone 2 — Model Pipeline

* implement model fetch/convert/quantize scripts
* generate manifest
* bundle one approved GGUF
* implement hash verification
* verify prompt metadata strategy

**Exit bar:** bundled model verifies successfully and manifest matches

### Milestone 3 — Safety Layer

* runtime profiles
* resource guard
* context manager
* output sanitizer
* watchdog
* lifecycle manager

**Exit bar:** safety tests pass, including oversized input rejection and interrupted-stream recovery

### Milestone 4 — Persistence

* SwiftData schema v1
* migration plan v1
* mapper
* autosave
* backup snapshots

**Exit bar:** round-trip, migration, and backup-recovery tests pass

### Milestone 5 — Engine Integration

* wrap llama.cpp in actor
* implement token counting
* implement streaming
* implement cancellation
* implement warmup

**Exit bar:** tiny-model integration test passes reliably

### Milestone 6 — Application Logic

* chat controller
* model controller
* conversation controller
* error handling
* title derivation

**Exit bar:** controller tests pass with mocks

### Milestone 7 — UI

* root window
* sidebar
* chat view
* composer
* settings
* error screens
* accessibility pass

**Exit bar:** end-to-end UI tests pass with mocks

### Milestone 8 — Hardening

* minimum supported hardware test
* long conversation trimming
* sleep/wake recovery
* soak tests
* benchmark baselines
* forbidden-symbol checks

**Exit bar:** release checklist passes in a release build

---

## 20. Localization

All user-facing strings live in `Localizable.xcstrings`.

### Required launch languages

* English
* German

### Representative strings

| Key                 | EN                                                                   | DE                                                                                     |
| ------------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| app.tagline         | AI that never phones home.                                           | KI, die niemals Daten nach Hause sendet.                                               |
| model.verifying     | Verifying AI model…                                                  | KI-Modell wird überprüft…                                                              |
| model.loading       | Loading AI model…                                                    | KI-Modell wird geladen…                                                                |
| model.ready         | Ready                                                                | Bereit                                                                                 |
| memory.title        | Not enough memory                                                    | Nicht genug Arbeitsspeicher                                                            |
| memory.body         | Close some apps and try again. Available: %@ · Required: %@          | Schließen Sie einige Apps und versuchen Sie es erneut. Verfügbar: %@ · Benötigt: %@    |
| disk.title          | Not enough free disk space                                           | Nicht genug freier Speicherplatz                                                       |
| disk.body           | Free up disk space and try again. Available: %@ · Required: %@       | Geben Sie Speicherplatz frei und versuchen Sie es erneut. Verfügbar: %@ · Benötigt: %@ |
| model.corrupt.title | AI model is damaged                                                  | KI-Modell ist beschädigt                                                               |
| model.corrupt.body  | Please delete and re-download Airplane AI from the App Store.        | Bitte löschen Sie Airplane AI und laden Sie es erneut aus dem App Store.               |
| context.title       | Message is too long                                                  | Nachricht ist zu lang                                                                  |
| context.body        | This message does not fit in the current context budget on this Mac. | Diese Nachricht passt auf diesem Mac nicht in das aktuelle Kontextbudget.              |
| chat.placeholder    | Ask anything…                                                        | Fragen Sie alles…                                                                      |
| chat.generating     | Thinking…                                                            | Denkt nach…                                                                            |
| chat.interrupted    | Interrupted                                                          | Unterbrochen                                                                           |
| action.retry        | Retry                                                                | Erneut versuchen                                                                       |

### Localization rules

* no hardcoded strings in Swift files
* use format placeholders, not string concatenation
* test with long German strings
* accessibility labels are localized too

---

## 21. Release Verification Checklist

Every release must pass all items below.

### Security and privacy

* [ ] `codesign -d --entitlements :- AirplaneAI.app` shows only `com.apple.security.app-sandbox`
* [ ] No `com.apple.security.network.*` entitlements exist
* [ ] No file/device/personal-information entitlements exist
* [ ] No analytics or crash-reporting SDKs are linked
* [ ] Forbidden symbol scan passes
* [ ] `lsof -i -P | grep AirplaneAI` returns empty during use
* [ ] Local firewall or network monitor shows zero connection attempts during a 30-minute session
* [ ] Privacy policy and App Store privacy answers match the product exactly

### Correctness

* [ ] All unit tests pass
* [ ] All UI tests pass
* [ ] All migration tests pass
* [ ] GGUF SHA-256 matches manifest
* [ ] Prompt formatter uses metadata template unless fallback is explicitly required
* [ ] Oversized current user message is rejected, not silently truncated
* [ ] Interrupted generation is recovered and labeled correctly on relaunch
* [ ] Conversations persist across restart
* [ ] Backup snapshot recovery works

### Performance

* [ ] Benchmark results are within 10% of accepted baselines
* [ ] TTFT is within the accepted target on the minimum supported machine
* [ ] No unbounded memory growth in 60-minute soak test
* [ ] Cancellation latency is acceptable on the minimum supported machine
* [ ] Cold launch to ready meets the accepted target

### Compatibility

* [ ] Tested on latest stable macOS
* [ ] Tested on latest public macOS beta when available
* [ ] Tested on minimum supported hardware: Apple Silicon, 16 GB unified memory
* [ ] Tested on one higher-end Apple Silicon machine
* [ ] Uncompressed app size is recorded for the release

### Build and provenance

* [ ] Release configuration used
* [ ] Debug logging compiled out
* [ ] `Package.resolved` matches approved llama.cpp revision
* [ ] Model manifest matches approved source model revision and GGUF hash
* [ ] License and notice files are bundled
* [ ] No unapproved dependency changes exist

---

## 22. Final Product Statement

Airplane AI is not trying to be everything. It is a deliberately narrow product:

* one app
* one local model
* one offline experience
* one strict privacy posture
* one reliable, supported hardware floor

The point of this spec is not to sound ambitious.
The point is to ship a local AI app that is honest, stable, fast enough, and impossible to mistake for a cloud product.

*Airplane AI Engineering Specification v3.0*
*Vienna · April 2026*

[1]: https://ai.google.dev/gemma/docs/core "https://ai.google.dev/gemma/docs/core"
[2]: https://developer.apple.com/documentation/packagedescription/package/dependency/package%28url%3Aexact%3A%29 "https://developer.apple.com/documentation/packagedescription/package/dependency/package%28url%3Aexact%3A%29"
[3]: https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes "https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes"
[4]: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox "https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox"
[5]: https://developer.apple.com/documentation/swiftdata/modelcontainer/migrationplan "https://developer.apple.com/documentation/swiftdata/modelcontainer/migrationplan"
[6]: https://ai.google.dev/gemma/docs/core/model_card_4?utm_source=chatgpt.com "Gemma 4 model card  |  Google AI for Developers"
[7]: https://github.com/ggml-org/llama.cpp/wiki/Templates-supported-by-llama_chat_apply_template "https://github.com/ggml-org/llama.cpp/wiki/Templates-supported-by-llama_chat_apply_template"
