#!/usr/bin/env bash
# =============================================================================
# Package the iOS standalone application (.app) into an .ipa archive and copy it
# into the dist/ directory under a versioned, product-named file.
#
# The iOS build (Ninja Multi-Config + the ios toolchain) produces a standalone
# ".app" bundle under "<build>/.../<CONFIG>/". An .ipa is simply a zip archive
# containing a top-level "Payload/" directory with the .app inside, so we stage
# the bundle into Payload/ and compress it.
#
# NOTE: the resulting .ipa is unsigned. It is suitable as a CI build artifact,
# but installing it on a device still requires code signing / a provisioning
# profile.
#
# Usage: packaging/ios/build_ipa.sh [CONFIG] [BUILD_DIR]
#   CONFIG     Release (default) or Debug.
#   BUILD_DIR  The CMake build directory containing the built .app bundle.
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

mkdir -p "$DIST_DIR"

APP="$(find_artifact app)"
[[ -n "$APP" ]] || die "No .app bundle found under $BUILD_DIR for config $CONFIG. Build the standalone first."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

log "Staging $(basename "$APP") into Payload/"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

OUTPUT="$DIST_DIR/$PRODUCT_SLUG-$VERSION-ios.ipa"
rm -f "$OUTPUT"
log "Creating archive"
( cd "$STAGE" && zip -qry "$OUTPUT" Payload )
log "Created $OUTPUT"
