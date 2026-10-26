#!/usr/bin/env bash
# Record Blade Concord Animation Showcase from Roblox Studio (when available).
# Offline fallback (no Studio): tools/render_anim_showcase_clip.py
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/media/anim-showcase-clip.mp4}"
mkdir -p "$(dirname "$OUT")"

echo "== Blade Concord — record Animation Showcase =="
echo "1. In another terminal:  rojo serve default.project.json"
echo "2. Studio → Connect Rojo → Play Solo"
echo "3. Wait Character + sabre, then press P (BC_Showcase)"
echo "4. This script captures the display until you Ctrl+C (aim ~1 full loop ≈ 2 min)"
echo
echo "Output: $OUT"
echo

if ! command -v ffmpeg >/dev/null; then
  echo "ffmpeg required" >&2
  exit 1
fi

DISPLAY_NUM="${DISPLAY:-:1}"
# x11grab primary display; adjust -video_size if needed
ffmpeg -y -f x11grab -framerate 30 -video_size 1280x720 -i "${DISPLAY_NUM}.0+0,0" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart \
  "$OUT"

echo "Wrote $OUT ($(wc -c <"$OUT") bytes)"
