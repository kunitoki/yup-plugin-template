#!/usr/bin/env bash
# =============================================================================
# Build a Linux tarball (.tar.gz) containing every built plugin format plus the
# standalone application and a .desktop entry.
#
# Usage: packaging/linux/build_archive.sh [CONFIG] [BUILD_DIR]
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$DIST_DIR"

ROOT="$STAGE/$PRODUCT_SLUG-$VERSION"
mkdir -p "$ROOT"

declare -a FOUND=()
stage_bundle() {
    local ext="$1" dest="$2"
    local artifact
    artifact="$(find_artifact "$ext")"
    if [[ -z "$artifact" ]]; then
        warn "No .$ext artifact found for $CONFIG; skipping."
        return
    fi
    log "Staging $(basename "$artifact") -> $dest"
    mkdir -p "$ROOT/$dest"
    cp -R "$artifact" "$ROOT/$dest/"
    FOUND+=("$ext")
}

stage_bundle vst3 "vst3"
stage_bundle clap "clap"
stage_bundle lv2  "lv2"

# The standalone application on Linux is a plain executable (no bundle).
STANDALONE="$(find "$BUILD_DIR" \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
    -path "*/$CONFIG/*" -name "${PROJECT_NAME}_standalone_plugin" -type f -print 2>/dev/null | head -n1)"
if [[ -n "$STANDALONE" ]]; then
    log "Staging standalone application"
    mkdir -p "$ROOT/bin"
    cp "$STANDALONE" "$ROOT/bin/$PRODUCT_SLUG"
    FOUND+=("standalone")
fi

[[ ${#FOUND[@]} -gt 0 ]] || die "No artifacts found under $BUILD_DIR for config $CONFIG. Build the plugin first."

# Desktop entry + icon for the standalone app.
if [[ -f "$PROJECT_ROOT/assets/app-icon.png" ]]; then
    mkdir -p "$ROOT/share/icons"
    cp "$PROJECT_ROOT/assets/app-icon.png" "$ROOT/share/icons/$PRODUCT_SLUG.png"
fi

mkdir -p "$ROOT/share/applications"
sed -e "s/@PRODUCT_NAME@/$PRODUCT_NAME/g" \
    -e "s/@PRODUCT_SLUG@/$PRODUCT_SLUG/g" \
    -e "s/@PLUGIN_DESCRIPTION@/A simple polyphonic instrument built with YUP./g" \
    "$PACKAGING_DIR/linux/app.desktop.in" > "$ROOT/share/applications/$PRODUCT_SLUG.desktop"

[[ -f "$PROJECT_ROOT/LICENSE" ]] && cp "$PROJECT_ROOT/LICENSE" "$ROOT/LICENSE"

ARCH="$(uname -m)"
OUTPUT="$DIST_DIR/$PRODUCT_SLUG-$VERSION-linux-$ARCH.tar.gz"
log "Creating archive"
tar -czf "$OUTPUT" -C "$STAGE" "$PRODUCT_SLUG-$VERSION"
log "Created $OUTPUT"
