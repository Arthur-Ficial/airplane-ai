# Airplane AI — Brand

Single source of truth for the visual identity. Derived from the canonical icon
at `branding/airplane-ai.png`.

## Icon

- `branding/airplane-ai.png` — 4096×4096 master, full artwork (airplane on off-white background). Use for app icons, pkg icons, Mac App Store listing.
- `branding/airplane-ai-transparent.png` — 4096×4096 glyph only, transparent background. Use for in-app UI (boot screen, welcome, about, chat empty state) and any compositing onto custom backgrounds.

## Color palette

Sampled from the new icon. Conservative, airline/aviation-inspired navy — not the vivid Apple system blue.

| Role | Hex | Notes |
|------|-----|-------|
| **Primary (Navy)** | `#0F4C81` | Airplane body. Links, primary buttons, CTAs, brand accents. |
| **Primary dark** | `#0A3960` | Hover / pressed state for primary buttons. |
| **Primary light** | `#E8EEF5` | Tinted backgrounds, subtle badges, selected rows. |
| **Primary tint** | `#F4F7FB` | Hero gradient tail, section wash backgrounds. |
| **Highlight** | `#1E6BB8` | Optional brighter navy for hover-lift on navy surfaces. |
| **Ink (dark bg)** | `#0D1117` | Primary dark section background. |
| **Ink-2** | `#161B22` | Raised dark surface, cards on dark sections. |
| **Text** | `#1A1A1A` | Primary body text. |
| **Text-2** | `#555555` | Secondary body text. |
| **Muted** | `#888888` | Tertiary text, metadata. |
| **Border light** | `#DFE6EF` | Hairlines, card borders on light surfaces. |
| **Border dark** | `#2A3038` | Hairlines on dark surfaces. |
| **Success** | `#16A34A` | Checkmarks, positive indicators. |

### Replaces

The previous vivid `#007AFF` (Apple system blue) palette is superseded by the navy palette above. All `--brand` CSS variables now point to `#0F4C81`.

## Typography

- System stack: `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`.
- Hero display: weight 800, letter-spacing `-1.2px`.
- Section headlines: weight 800, letter-spacing `-0.8px`.
- Body: weight 400, line-height 1.55.

## Motion

- Default transition `.15s ease`. No parallax. No large continuous animations.
- Respect `prefers-reduced-motion`.

## Social share (OG)

`site/img/og-image.png` — 1200×630 PNG. Layout: transparent airplane glyph on `#F4F7FB` background, title in `#0D1117`, tagline in `#555`, closing line in primary navy `#0F4C81`.

## Regeneration

- App icons: `./scripts/generate-icon.sh --force` → rasterizes `branding/airplane-ai.png` → `Sources/AirplaneAI/Resources/AppIcon.icns`.
- Website icons: `sips -z <px> <px> branding/airplane-ai.png --out site/img/icon-<px>.png`.
- OG image: documented in `scripts/generate-og-image.sh` (uses ImageMagick + Helvetica).
