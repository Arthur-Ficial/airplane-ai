# Airplane AI — Mac App Store Submission Checklist

**Price:** €29.99 (Tier 30)
**Bundle ID:** `com.franzai.airplane-ai`
**Team:** Franz Enzenhofer (7D2YX5DQ6M)
**SKU:** airplane-ai-v1
**Category:** Productivity (primary), Developer Tools (secondary)
**Age Rating:** 4+

## Localization

Primary: English (U.S.)

## App Store Connect Record

### Name
Airplane AI

### Subtitle (30 chars max)
Private offline AI chat

### Promotional Text (170 chars)
AI that never phones home. Your conversations stay on your Mac — enforced by the kernel. No accounts, no subscriptions, no telemetry. One purchase, yours forever.

### Keywords (100 chars)
ai,chat,offline,private,local,llm,gemma,assistant,airplane,gpt,writing,coding,productivity

### Support URL
https://airplane-ai.franzai.com

### Marketing URL
https://airplane-ai.franzai.com

### Copyright
© 2026 Franz Enzenhofer

## Pricing

| Territory | Price | Tier |
|-----------|-------|------|
| All | €29.99 (Euro Zone) | Tier 30 |

Equivalent: $29.99 USD, £24.99 GBP.

## Screenshots (required)

Mac App Store requires 1280×800 or 2560×1600 PNG/JPEG, at least 1, up to 10 per display size.

Need 10 screenshots from the real app. Captured via `make screenshots`:
- `build/screenshots/screen-chat.png`
- `build/screenshots/screen-code.png`
- `build/screenshots/screen-travel.png`
- `build/screenshots/screen-writing.png`
- `build/screenshots/screen-translate.png`
- `build/screenshots/screen-creative.png`
- `build/screenshots/screen-debugging.png`
- `build/screenshots/screen-regex.png`
- `build/screenshots/screen-analysis.png`
- `build/screenshots/screen-settings.png`

## App Icon

1024×1024 PNG without alpha, no rounded corners (App Store adds them).
Source: `Sources/AirplaneAI/Resources/AppIcon.icns` (icon_512x512@2x)

## Review Notes

```
Airplane AI is a fully-offline AI assistant. It ships with a bundled ~4.5 GB
model file (Gemma 3n E4B Q4_K_M, Apache 2.0 licensed). The app has only the
app-sandbox entitlement plus device.audio-input (for on-device speech
dictation via SFSpeechRecognizer with requiresOnDeviceRecognition = true).

It performs NO network activity. You can verify by running with Little Snitch
or Airport mode — all features remain functional.

Test account: not required (no account system exists).
Demo: launch, accept onboarding, ask "How many feet in a mile?". Response
streams in 2–5 seconds on Apple Silicon.
```

## Export Compliance

**Uses Encryption:** NO

Justification: the app does not implement any custom cryptography and does not
call encryption APIs beyond what macOS itself uses for code signing. Quantized
model weights (GGUF) are not encrypted.

## Privacy

### Privacy Policy URL
https://airplane-ai.franzai.com/privacy

### Data Collection
**Does the app collect data?** NO

All categories: **Not collected.**

## Entitlements (verified by CI)

```xml
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.device.audio-input</key><true/>
<key>com.apple.security.files.user-selected.read-only</key><true/>
```

Enforced by `Tools/ci/verify-entitlements.sh` on every build.

## Info.plist Keys

- `NSMicrophoneUsageDescription`: "Airplane AI uses your microphone for on-device speech-to-text dictation. Audio never leaves your Mac."
- `NSSpeechRecognitionUsageDescription`: "Airplane AI uses on-device speech recognition to transcribe your voice into text. Speech is never sent to Apple or any server."

## Build & Submit Workflow

```bash
# 1. Build signed release
make dist                            # creates build/AirplaneAI.app + .pkg

# 2. Verify gates
make verify                          # entitlements, network symbols, deps, manifest
make verify-bundle                   # sandbox layout OK
make test                            # 201 tests pass

# 3. Notarize
./scripts/notarize.sh                # xcrun notarytool submit → staple

# 4. Upload via Transporter or xcrun altool
xcrun altool --upload-app -f build/AirplaneAI.pkg \
  -u "f.enzenhofer@gmail.com" -p "@keychain:AC_PASSWORD"
```

## Final Pre-Submit Checks

- [ ] Signed with `Developer ID Application: Franz Enzenhofer (7D2YX5DQ6M)`
- [ ] Entitlements verified (only app-sandbox + audio-input + files.user-selected.read-only)
- [ ] Version `0.3.0` in `.version` matches Info.plist CFBundleShortVersionString
- [ ] 10 marketing screenshots at 1280×800 or 2560×1600
- [ ] 1024×1024 icon exported without alpha
- [ ] Privacy policy reachable at https://airplane-ai.franzai.com/privacy
- [ ] Test deployment reachable at https://airplane-ai.franzai.com
- [ ] `make screenshots` regenerated with final UI
- [ ] README.md updated to point to landing page
- [ ] docs/RELEASE_NOTES.md contains 0.3.0 entry
- [ ] All 201 tests pass (`make test`)
- [ ] `make verify-bundle` passes on final .app
