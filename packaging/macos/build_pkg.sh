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
#   INSTALLER_SIGNING_IDENTITY (a "Developer ID Installer: ..." identity),
#   APPLICATION_SIGNING_IDENTITY (a "Developer ID Application: ..." identity,
#     used to codesign the plugin/app bundles with the hardened runtime).
#
# Notarization (optional; runs only when credentials are provided and the
# installer was signed). Provide either a stored notarytool keychain profile:
#   NOTARY_KEYCHAIN_PROFILE
# or an Apple ID credential triple:
#   NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD (an app-specific password)
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
# Codesign the staged bundles with the hardened runtime (Developer ID
# Application). Skipped entirely when no identity is provided, so the default
# build still produces an unsigned installer.
# -----------------------------------------------------------------------------
if [[ -n "${APPLICATION_SIGNING_IDENTITY:-}" ]]; then
    command -v codesign >/dev/null || die "codesign not found (install the Xcode command line tools)."
    log "Codesigning staged bundles with: $APPLICATION_SIGNING_IDENTITY"
    while IFS= read -r -d '' bundle; do
        log "Signing $(basename "$bundle")"
        codesign --force --timestamp --options runtime \
            --sign "$APPLICATION_SIGNING_IDENTITY" "$bundle"
    done < <(find "$STAGE" \( -name '*.vst3' -o -name '*.clap' -o -name '*.component' \
        -o -name '*.lv2' -o -name '*.app' \) -maxdepth 3 -print0)
else
    log "No APPLICATION_SIGNING_IDENTITY set; leaving bundles unsigned."
fi

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

# -----------------------------------------------------------------------------
# Notarize + staple. Only runs when the installer was signed (an unsigned pkg
# cannot be notarized) and notarization credentials are available.
# -----------------------------------------------------------------------------
if [[ -z "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
    [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}${NOTARY_APPLE_ID:-}" ]] \
        && warn "Notarization skipped: the installer is unsigned (set INSTALLER_SIGNING_IDENTITY)."
elif [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
    log "Notarizing with keychain profile: $NOTARY_KEYCHAIN_PROFILE"
    xcrun notarytool submit "$OUTPUT_PKG" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
    xcrun stapler staple "$OUTPUT_PKG"
    log "Notarized and stapled $OUTPUT_PKG"
elif [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_TEAM_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
    log "Notarizing with Apple ID: $NOTARY_APPLE_ID"
    xcrun notarytool submit "$OUTPUT_PKG" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait
    xcrun stapler staple "$OUTPUT_PKG"
    log "Notarized and stapled $OUTPUT_PKG"
else
    log "No notarization credentials set; skipping notarization."
fi
