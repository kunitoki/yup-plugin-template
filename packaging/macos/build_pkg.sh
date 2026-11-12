#!/usr/bin/env bash
# =============================================================================
# Build a macOS installer package (.pkg).
#
# Collects every plugin format that was built (VST3, CLAP, AU component, LV2)
# plus the standalone .app and produces a single signed-or-unsigned installer
# that drops each artifact into its standard macOS install location.
#
# Usage:
#   packaging/macos/build_pkg.sh [CONFIG] [BUILD_DIR]
#
# Environment overrides: PRODUCT_NAME, COMPANY_NAME, BUNDLE_ID, DIST_DIR,
#   INSTALLER_SIGNING_IDENTITY (a "Developer ID Installer: ..." identity).
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

[[ "$(uname -s)" == "Darwin" ]] || die "macOS packaging must run on macOS."
command -v pkgbuild >/dev/null     || die "pkgbuild not found (install the Xcode command line tools)."
command -v productbuild >/dev/null || die "productbuild not found (install the Xcode command line tools)."

STAGE="$(mktemp -d)"
COMPONENTS_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE" "$COMPONENTS_DIR"' EXIT

mkdir -p "$DIST_DIR"

# -----------------------------------------------------------------------------
# Collect built artifacts into a staging tree mirroring the install layout.
# -----------------------------------------------------------------------------
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

stage_bundle vst3      "Library/Audio/Plug-Ins/VST3"
stage_bundle clap      "Library/Audio/Plug-Ins/CLAP"
stage_bundle component "Library/Audio/Plug-Ins/Components"
stage_bundle lv2       "Library/Audio/Plug-Ins/LV2"
stage_bundle app       "Applications"

[[ ${#FOUND[@]} -gt 0 ]] || die "No artifacts found under $BUILD_DIR for config $CONFIG. Build the plugin first."

# -----------------------------------------------------------------------------
# Build the component package, then wrap it with a distribution installer.
# -----------------------------------------------------------------------------
COMPONENT_PKG="$COMPONENTS_DIR/$PRODUCT_SLUG-component.pkg"

log "Building component package"
pkgbuild \
    --root "$STAGE" \
    --identifier "$BUNDLE_ID.pkg" \
    --version "$VERSION" \
    --install-location "/" \
    "$COMPONENT_PKG"

DIST_XML="$COMPONENTS_DIR/distribution.xml"
LICENSE_ARG=()
[[ -f "$PROJECT_ROOT/LICENSE" ]] && LICENSE_ARG=(--resource "$PROJECT_ROOT/LICENSE")

cat > "$DIST_XML" <<XML
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>$PRODUCT_NAME $VERSION</title>
    <organization>$BUNDLE_ID</organization>
    <options customize="allow" require-scripts="false" hostArchitectures="arm64,x86_64"/>
$( [[ -f "$PROJECT_ROOT/LICENSE" ]] && echo "    <license file=\"LICENSE\"/>" )
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" title="$PRODUCT_NAME">
        <pkg-ref id="$BUNDLE_ID.pkg"/>
    </choice>
    <pkg-ref id="$BUNDLE_ID.pkg" version="$VERSION" onConclusion="none">$(basename "$COMPONENT_PKG")</pkg-ref>
</installer-gui-script>
XML

OUTPUT_PKG="$DIST_DIR/$PRODUCT_SLUG-$VERSION-macOS.pkg"

PRODUCT_ARGS=(
    --distribution "$DIST_XML"
    --package-path "$COMPONENTS_DIR"
)
[[ -f "$PROJECT_ROOT/LICENSE" ]] && PRODUCT_ARGS+=(--resources "$PROJECT_ROOT")

if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
    log "Signing installer with: $INSTALLER_SIGNING_IDENTITY"
    PRODUCT_ARGS+=(--sign "$INSTALLER_SIGNING_IDENTITY")
fi

log "Building distribution installer"
productbuild "${PRODUCT_ARGS[@]}" "$OUTPUT_PKG"

log "Created $OUTPUT_PKG"
