#!/usr/bin/env bash
# Regenerate site/img/og-image.png (1200×630) from branding/airplane-ai-transparent.png
# using the brand navy palette documented in branding/BRAND.md.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

HELVETICA="/System/Library/Fonts/Helvetica.ttc"
BG='#F4F7FB'        # --brand-tint
INK='#0D1117'       # headline
SUB='#555555'       # tagline
NAVY='#0F4C81'      # brand primary

magick -size 1200x630 xc:"$BG" \
  \( branding/airplane-ai-transparent.png -resize 420x420 \) -gravity west -geometry +80+0 -composite \
  -gravity east -font "$HELVETICA" -pointsize 56 -fill "$INK" -annotate +100-80 'Airplane AI' \
  -font "$HELVETICA" -pointsize 26 -fill "$SUB" -annotate +100-20 'The NDA-safe AI that even works in airplane mode.' \
  -font "$HELVETICA" -pointsize 22 -fill "$NAVY" -annotate +100+40 'Runs entirely on your Mac. No cloud. No leaks.' \
  site/img/og-image.png

echo "→ site/img/og-image.png ($(sips -g pixelWidth -g pixelHeight site/img/og-image.png | grep -E 'pixel' | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//'))"
