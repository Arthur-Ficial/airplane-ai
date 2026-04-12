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
  <!-- Matches the AirplaneGlyph used in BootScreen / Welcome / About.
       White rounded-rect background, accent-blue tinted circle, SF-Symbol-style airplane. -->
  <rect x="64" y="64" width="896" height="896" rx="200" ry="200" fill="#FFFFFF"/>
  <circle cx="512" cy="512" r="300" fill="#007AFF" fill-opacity="0.12"/>
  <!-- Stylized airplane silhouette, rotated -20deg, centered at (512,512). -->
  <g transform="translate(512 512) rotate(-20)">
    <path d="M -240 -20
             L -30 -50
             L 50 -220
             L 120 -220
             L 85 -55
             L 210 -45
             L 250 -100
             L 290 -100
             L 255 -25
             L 300 -5
             L 300 5
             L 255 25
             L 290 100
             L 250 100
             L 210 45
             L 85 55
             L 120 220
             L 50 220
             L -30 50
             L -240 20
             Z"
          fill="#007AFF"/>
  </g>
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
