#!/usr/bin/env bash
# =============================================================================
# Generate platform icon files from the source PNG (assets/app-icon.png).
#
#   - macOS : assets/app-icon.icns  (requires sips + iconutil, macOS only)
#   - Windows: assets/app-icon.ico  (requires ImageMagick `magick`/`convert`,
#              otherwise the existing checked-in .ico is kept)
#
# Usage: packaging/icons/generate_icons.sh [SOURCE_PNG]
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HERE/../.." && pwd)"
ASSETS_DIR="$PROJECT_ROOT/assets"
SOURCE_PNG="${1:-$ASSETS_DIR/app-icon.png}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "$SOURCE_PNG" ]] || die "Source icon not found: $SOURCE_PNG"

# -----------------------------------------------------------------------------
# macOS .icns
# -----------------------------------------------------------------------------
if [[ "$(uname -s)" == "Darwin" ]] && command -v sips >/dev/null && command -v iconutil >/dev/null; then
    log "Generating app-icon.icns"
    ICONSET="$(mktemp -d)/app-icon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z "$size" "$size"         "$SOURCE_PNG" --out "$ICONSET/icon_${size}x${size}.png"     >/dev/null
        sips -z "$((size*2))" "$((size*2))" "$SOURCE_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ASSETS_DIR/app-icon.icns"
    rm -rf "$(dirname "$ICONSET")"
    log "Wrote $ASSETS_DIR/app-icon.icns"
else
    warn "Skipping .icns (needs macOS with sips + iconutil)."
fi

# -----------------------------------------------------------------------------
# Windows .ico
# -----------------------------------------------------------------------------
if command -v magick >/dev/null; then
    CONVERT=(magick "$SOURCE_PNG")
elif command -v convert >/dev/null; then
    CONVERT=(convert "$SOURCE_PNG")
else
    CONVERT=()
fi

if [[ ${#CONVERT[@]} -gt 0 ]]; then
    log "Generating app-icon.ico"
    "${CONVERT[@]}" -define icon:auto-resize=16,32,48,64,128,256 "$ASSETS_DIR/app-icon.ico"
    log "Wrote $ASSETS_DIR/app-icon.ico"
else
    warn "Skipping .ico (install ImageMagick to regenerate; keeping existing assets/app-icon.ico)."
fi
