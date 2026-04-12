#!/bin/zsh
# Generate AppIcon.icns from a programmatically rendered SVG.
# Output: Sources/AirplaneAI/Resources/AppIcon.icns
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT_DIR/Sources/AirplaneAI/Resources"
ICONSET="$ROOT_DIR/build/AppIcon.iconset"
SVG="$ROOT_DIR/build/AppIcon.svg"

mkdir -p "$ICONSET" "$OUT_DIR"

cat > "$SVG" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0B1F3A"/>
      <stop offset="1" stop-color="#17375C"/>
    </linearGradient>
    <linearGradient id="wing" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#BFD4EE"/>
    </linearGradient>
    <radialGradient id="glow" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#FFD47A" stop-opacity="0.75"/>
      <stop offset="1" stop-color="#FFD47A" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <!-- rounded square background -->
  <rect x="64" y="64" width="896" height="896" rx="200" ry="200" fill="url(#sky)"/>
  <!-- subtle glow behind the plane -->
  <circle cx="512" cy="560" r="380" fill="url(#glow)"/>
  <!-- paper plane -->
  <g transform="translate(200,220) rotate(-6 312 296)">
    <polygon points="0,280 624,0 480,320 280,240 420,420 0,280" fill="url(#wing)"/>
    <polygon points="0,280 280,240 420,420 0,280" fill="#8FB0D7" opacity="0.55"/>
    <polygon points="624,0 480,320 420,420 624,0" fill="#DDE8F5" opacity="0.35"/>
  </g>
  <!-- tiny airstream dot -->
  <circle cx="820" cy="200" r="16" fill="#FFD47A" opacity="0.9"/>
  <circle cx="720" cy="260" r="10" fill="#FFD47A" opacity="0.6"/>
</svg>
SVG

render_png() {
    local size=$1
    local out=$2
    # Use Python with PyObjC / CoreGraphics via `qlmanage` — fall back to sips with a
    # bitmap rendered by WebKit via the `textutil` route isn't reliable. Use rsvg-convert if present.
    if command -v rsvg-convert >/dev/null 2>&1; then
        rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
    elif command -v qlmanage >/dev/null 2>&1; then
        qlmanage -t -s "$size" -o /tmp -z "$SVG" >/dev/null 2>&1
        mv "/tmp/$(basename "$SVG").png" "$out"
    else
        print -u2 "No SVG→PNG renderer found (install librsvg: brew install librsvg)"
        exit 1
    fi
}

# Apple requires 1024,512@2x,512,256@2x,256,128@2x,128,64,32@2x,32,16@2x,16
for spec in "16:icon_16x16" "32:icon_16x16@2x" "32:icon_32x32" "64:icon_32x32@2x" \
            "128:icon_128x128" "256:icon_128x128@2x" "256:icon_256x256" "512:icon_256x256@2x" \
            "512:icon_512x512" "1024:icon_512x512@2x"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    render_png "$size" "$ICONSET/${name}.png"
done

iconutil -c icns -o "$OUT_DIR/AppIcon.icns" "$ICONSET"
print "==> AppIcon.icns written to $OUT_DIR"
