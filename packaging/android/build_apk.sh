#!/usr/bin/env bash
# =============================================================================
# Collect the Android application package (.apk) produced by the Gradle build
# and copy it into the dist/ directory under a versioned, product-named file.
#
# The YUP Android build generates a Gradle project inside the CMake build
# directory (see yup_android.cmake). Running "./gradlew assemble" emits the APKs
# under "<build>/app/build/outputs/apk/<buildType>/". Without a signing config
# the release variant is the unsigned "app-release-unsigned.apk".
#
# Usage: packaging/android/build_apk.sh [CONFIG] [BUILD_DIR]
#   CONFIG     Release (default) or Debug - selects the Gradle build variant.
#   BUILD_DIR  The CMake build directory that contains the Gradle project.
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

mkdir -p "$DIST_DIR"

# Gradle build-type directory is lower-case (release / debug).
VARIANT="$(printf '%s' "$CONFIG" | tr '[:upper:]' '[:lower:]')"

# Prefer the canonical Gradle output location, then fall back to a broad search
# so the script keeps working if the module layout changes.
APK=""
for candidate in "$BUILD_DIR/app/build/outputs/apk/$VARIANT"/*.apk; do
    [[ -f "$candidate" ]] && APK="$candidate" && break
done

if [[ -z "$APK" ]]; then
    APK="$(find "$BUILD_DIR" \
        \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
        -path "*/outputs/apk/$VARIANT/*" -name '*.apk' -type f -print 2>/dev/null \
        | head -n1)"
fi

[[ -n "$APK" ]] || die "No $VARIANT .apk found under $BUILD_DIR. Run \"./gradlew assemble\" first."

OUTPUT="$DIST_DIR/$PRODUCT_SLUG-$VERSION-android.apk"
log "Staging $(basename "$APK")"
cp "$APK" "$OUTPUT"
log "Created $OUTPUT"
