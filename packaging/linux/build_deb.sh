#!/usr/bin/env bash
# =============================================================================
# Build a Debian package (.deb) that installs every built plugin format plus the
# standalone application system-wide.
#
#   VST3 -> /usr/lib/vst3        CLAP -> /usr/lib/clap
#   LV2  -> /usr/lib/lv2         app  -> /usr/bin + .desktop entry
#
# Usage: packaging/linux/build_deb.sh [CONFIG] [BUILD_DIR]
# Requires: dpkg-deb
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

command -v dpkg-deb >/dev/null || die "dpkg-deb not found (install the dpkg package)."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$DIST_DIR"

# Lowercase, hyphenated package name as required by Debian policy.
PKG_NAME="$(echo "$PRODUCT_SLUG" | tr '[:upper:]' '[:lower:]')"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

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
    mkdir -p "$STAGE/$dest"
    cp -R "$artifact" "$STAGE/$dest/"
    FOUND+=("$ext")
}

stage_bundle vst3 "usr/lib/vst3"
stage_bundle clap "usr/lib/clap"
stage_bundle lv2  "usr/lib/lv2"

STANDALONE="$(find "$BUILD_DIR" \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
    -path "*/$CONFIG/*" -name "${PROJECT_NAME}_standalone_plugin" -type f -print 2>/dev/null | head -n1)"
if [[ -n "$STANDALONE" ]]; then
    log "Staging standalone application"
    mkdir -p "$STAGE/usr/bin"
    cp "$STANDALONE" "$STAGE/usr/bin/$PKG_NAME"
    chmod 755 "$STAGE/usr/bin/$PKG_NAME"

    if [[ -f "$PROJECT_ROOT/assets/app-icon.png" ]]; then
        mkdir -p "$STAGE/usr/share/icons/hicolor/512x512/apps"
        cp "$PROJECT_ROOT/assets/app-icon.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/$PKG_NAME.png"
    fi

    mkdir -p "$STAGE/usr/share/applications"
    sed -e "s/@PRODUCT_NAME@/$PRODUCT_NAME/g" \
        -e "s/@PRODUCT_SLUG@/$PKG_NAME/g" \
        -e "s/@PLUGIN_DESCRIPTION@/A simple polyphonic instrument built with YUP./g" \
        "$PACKAGING_DIR/linux/app.desktop.in" > "$STAGE/usr/share/applications/$PKG_NAME.desktop"
    FOUND+=("standalone")
fi

[[ ${#FOUND[@]} -gt 0 ]] || die "No artifacts found under $BUILD_DIR for config $CONFIG. Build the plugin first."

# Control metadata.
INSTALLED_KB="$(du -sk "$STAGE" | cut -f1)"
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $PKG_NAME
Version: $VERSION
Section: sound
Priority: optional
Architecture: $ARCH
Maintainer: $COMPANY_NAME
Installed-Size: $INSTALLED_KB
Description: $PRODUCT_NAME
 A simple polyphonic instrument built with YUP.
 Installs the VST3, CLAP and LV2 plugin formats and a standalone application.
CONTROL

OUTPUT="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
log "Building Debian package"
dpkg-deb --build --root-owner-group "$STAGE" "$OUTPUT"
log "Created $OUTPUT"
