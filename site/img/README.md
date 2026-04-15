## Screenshot Workflow

Regenerate product screenshots with:

```bash
make screenshots
```

What it does:

1. Builds `AirplaneAI.app`
2. Seeds deterministic sample conversations
3. Launches the app in `AIRPLANE_SCREENSHOT_MODE=1`
4. Captures fixed-window screenshots
5. Crops chat screenshots to the detail pane
6. Writes matching `.png` and `.webp` assets into `site/img/`

Current exported assets:

- `screen-chat`
- `screen-code`
- `screen-travel`
- `screen-writing`
- `screen-translate`
- `screen-creative`
- `screen-debugging`
- `screen-regex`
- `screen-analysis`
- `screen-settings`

Determinism rules:

- Light appearance forced
- Onboarding completed before capture
- Seeded sample store replaces prior demo content
- Screenshot mode disables transient UI that would create pixel drift
