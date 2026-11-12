#!/usr/bin/env bash
# =============================================================================
# Shared helpers for the packaging scripts.
#
# These values mirror the CMake configuration (CMakeLists.txt) and the VERSION
# file. Override any of them from the environment before invoking a packaging
# script if your fork changes the product naming.
# =============================================================================
set -euo pipefail

PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$PACKAGING_DIR/.." && pwd)"

# The internal target name (see PROJECT_NAME in CMakeLists.txt).
PROJECT_NAME="${PROJECT_NAME:-YupPlugin}"

# The user-facing product name (see PRODUCT_NAME in CMakeLists.txt). This is the
# name of the generated standalone .app bundle.
PRODUCT_NAME="${PRODUCT_NAME:-YUP Instrument}"

# The vendor / author (see COMPANY_NAME in CMakeLists.txt).
COMPANY_NAME="${COMPANY_NAME:-YUP Audio}"

# The reverse-domain bundle identifier prefix (see BUNDLE_ID in CMakeLists.txt).
BUNDLE_ID="${BUNDLE_ID:-audio.yup.yupplugin}"

# Build configuration and directory.
CONFIG="${CONFIG:-Release}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"

# Output directory for the finished installers / archives.
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

# Version string read from the VERSION file.
VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"

# A filesystem-friendly product slug (no spaces).
PRODUCT_SLUG="${PRODUCT_NAME// /-}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Find the first bundle/file with the given extension produced by the build.
# Searches the common config directory as well as the VST3-specific subtree,
# skipping third-party bundles under externals/.
# Usage: find_artifact <extension>
find_artifact() {
    local ext="$1"
    find "$BUILD_DIR" \
        \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
        -path "*/$CONFIG/*" -name "*.$ext" -print 2>/dev/null \
        | grep -v '\.dSYM' \
        | head -n 1
}
