#!/usr/bin/env bash
# =============================================================================
# Build a WebAssembly tarball (.tar.gz) containing the Emscripten standalone
# application: the HTML shell plus every file Emscripten emits alongside it
# (.js, .wasm, .data, worker scripts, source maps, ...) and the mini-coi.js
# cross-origin-isolation helper.
#
# Usage: packaging/wasm/build_archive.sh [CONFIG] [BUILD_DIR]
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

mkdir -p "$DIST_DIR"

# The Emscripten standalone emits "<product>.html" into the per-config output
# directory. Locate it, skipping third-party bundles under externals/_deps.
HTML="$(find "$BUILD_DIR" \
    \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
    -path "*/$CONFIG/*" -name '*.html' -type f -print 2>/dev/null | head -n1)"
[[ -n "$HTML" ]] || die "No Emscripten .html output found under $BUILD_DIR for config $CONFIG. Build the WASM standalone first."

OUT_DIR="$(dirname "$HTML")"
STEM="$(basename "$HTML" .html)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ROOT="$STAGE/$PRODUCT_SLUG-$VERSION"
mkdir -p "$ROOT"

log "Staging WebAssembly standalone \"$STEM\""

# Copy every file that shares the HTML stem (.html/.js/.wasm/.data/.wasm.map and
# the pthread / wasm-worker / audio-worklet helper scripts).
shopt -s nullglob
for f in "$OUT_DIR/$STEM".*; do
    cp "$f" "$ROOT/"
done
shopt -u nullglob

# The cross-origin-isolation shim required to serve the SharedArrayBuffer build.
if [[ -f "$OUT_DIR/mini-coi.js" ]]; then
    cp "$OUT_DIR/mini-coi.js" "$ROOT/"
fi

# Expose the entry shell as index.html so the archive can be served as-is.
if [[ -f "$ROOT/$STEM.html" ]]; then
    cp "$ROOT/$STEM.html" "$ROOT/index.html"
fi

[[ -f "$PROJECT_ROOT/LICENSE" ]] && cp "$PROJECT_ROOT/LICENSE" "$ROOT/LICENSE"

OUTPUT="$DIST_DIR/$PRODUCT_SLUG-$VERSION-wasm.tar.gz"
log "Creating archive"
tar -czf "$OUTPUT" -C "$STAGE" "$PRODUCT_SLUG-$VERSION"
log "Created $OUTPUT"
