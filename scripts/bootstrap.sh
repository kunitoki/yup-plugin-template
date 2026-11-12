#!/usr/bin/env bash
# =============================================================================
# Bootstrap / rename the template for your own plugin.
#
# Replaces the default template identifiers (project name, product name,
# company, bundle id, 4-character codes, description, url, e-mail) across every
# tracked file, skipping the yup submodule and build output.
#
# Run it once right after creating a repository from the template:
#
#     ./scripts/bootstrap.sh                 # interactive
#     ./scripts/bootstrap.sh --name AcmeVerb --product "Acme Verb" \
#         --company "Acme Audio" --bundle-id com.acme.acmeverb
#     ./scripts/bootstrap.sh --dry-run       # preview the changes only
#
# Pass --help for the full list of options.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# --- Current template defaults (the values being replaced). -------------------
OLD_NAME="YupPlugin"
OLD_PRODUCT="YUP Instrument"
OLD_COMPANY="YUP Audio"
OLD_BUNDLE_ID="audio.yup.yupplugin"
OLD_CODE="YpIn"
OLD_MANUFACTURER="Yup!"
OLD_DESCRIPTION="A simple polyphonic instrument built with YUP."
OLD_URL="https://github.com/kunitoki/yup-plugin-template"
OLD_EMAIL="support@yourcompany.com"

# --- New values (populated from flags / prompts). -----------------------------
NEW_NAME=""
NEW_PRODUCT=""
NEW_COMPANY=""
NEW_BUNDLE_ID=""
NEW_CODE=""
NEW_MANUFACTURER=""
NEW_DESCRIPTION=""
NEW_URL=""
NEW_EMAIL=""
DRY_RUN=0

bold()  { printf '\033[1m%s\033[0m' "$*"; }
log()   { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Bootstrap the YUP plugin template for your own plugin.

Usage: scripts/bootstrap.sh [options]

Options:
  --name <id>             Internal project/target name (no spaces, e.g. AcmeVerb)
  --product <name>        User-facing product name (e.g. "Acme Verb")
  --company <name>        Company / author name (e.g. "Acme Audio")
  --bundle-id <id>        Reverse-domain bundle id prefix (e.g. com.acme.acmeverb)
  --code <AbCd>           4-character plugin code (AU subtype / AAX product id)
  --manufacturer <AbCd>   4-character manufacturer code (one uppercase letter)
  --description <text>    Short plugin description
  --url <url>             Website / support URL
  --email <email>         Contact e-mail
  --dry-run               Show what would change without writing anything
  -h, --help              Show this help

Any value omitted on the command line is prompted for interactively (press
Enter to keep the current value unchanged).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)         NEW_NAME="$2"; shift 2 ;;
        --product)      NEW_PRODUCT="$2"; shift 2 ;;
        --company)      NEW_COMPANY="$2"; shift 2 ;;
        --bundle-id)    NEW_BUNDLE_ID="$2"; shift 2 ;;
        --code)         NEW_CODE="$2"; shift 2 ;;
        --manufacturer) NEW_MANUFACTURER="$2"; shift 2 ;;
        --description)  NEW_DESCRIPTION="$2"; shift 2 ;;
        --url)          NEW_URL="$2"; shift 2 ;;
        --email)        NEW_EMAIL="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              die "unknown option: $1 (try --help)" ;;
    esac
done

# Prompt for any value not supplied on the command line.
prompt() {
    local var="$1" label="$2" current="$3" answer
    [[ -n "${!var}" ]] && return 0
    read -r -p "$(bold "$label") [$current]: " answer || true
    printf -v "$var" '%s' "${answer:-$current}"
}

if [[ -t 0 ]]; then
    prompt NEW_NAME         "Project name (no spaces)" "$OLD_NAME"
    prompt NEW_PRODUCT      "Product name"             "$OLD_PRODUCT"
    prompt NEW_COMPANY      "Company name"             "$OLD_COMPANY"
    prompt NEW_BUNDLE_ID    "Bundle id prefix"         "$OLD_BUNDLE_ID"
    prompt NEW_CODE         "Plugin code (4 chars)"    "$OLD_CODE"
    prompt NEW_MANUFACTURER "Manufacturer code (4 chars)" "$OLD_MANUFACTURER"
    prompt NEW_DESCRIPTION  "Description"              "$OLD_DESCRIPTION"
    prompt NEW_URL          "Website / support URL"    "$OLD_URL"
    prompt NEW_EMAIL        "Contact e-mail"           "$OLD_EMAIL"
else
    # Non-interactive: keep current values for anything not passed as a flag.
    NEW_NAME="${NEW_NAME:-$OLD_NAME}"
    NEW_PRODUCT="${NEW_PRODUCT:-$OLD_PRODUCT}"
    NEW_COMPANY="${NEW_COMPANY:-$OLD_COMPANY}"
    NEW_BUNDLE_ID="${NEW_BUNDLE_ID:-$OLD_BUNDLE_ID}"
    NEW_CODE="${NEW_CODE:-$OLD_CODE}"
    NEW_MANUFACTURER="${NEW_MANUFACTURER:-$OLD_MANUFACTURER}"
    NEW_DESCRIPTION="${NEW_DESCRIPTION:-$OLD_DESCRIPTION}"
    NEW_URL="${NEW_URL:-$OLD_URL}"
    NEW_EMAIL="${NEW_EMAIL:-$OLD_EMAIL}"
fi

# --- Validation. --------------------------------------------------------------
[[ "$NEW_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] \
    || die "project name '$NEW_NAME' must be a valid identifier (letters, digits, underscore; no spaces)"
[[ ${#NEW_CODE} -eq 4 ]]         || warn "plugin code '$NEW_CODE' should be exactly 4 characters"
[[ ${#NEW_MANUFACTURER} -eq 4 ]] || warn "manufacturer code '$NEW_MANUFACTURER' should be exactly 4 characters"
[[ "$NEW_MANUFACTURER" =~ [A-Z] ]] || warn "manufacturer code should contain at least one uppercase letter"
[[ "$NEW_BUNDLE_ID" =~ ^[A-Za-z0-9.-]+$ ]] \
    || warn "bundle id '$NEW_BUNDLE_ID' is not a typical reverse-domain identifier"

# Replace OLD -> NEW (literal, global) in every tracked text file, skipping the
# submodule, build output and this script itself.
replace_in_tree() {
    local search="$1" replacement="$2"
    [[ "$search" == "$replacement" ]] && return 0
    local files
    files="$(grep -rlIF \
        --exclude-dir=yup --exclude-dir=build --exclude-dir=dist \
        --exclude-dir=.git --exclude-dir=scripts \
        -- "$search" . 2>/dev/null || true)"
    [[ -z "$files" ]] && return 0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ $DRY_RUN -eq 1 ]]; then
            printf '    %s\n' "${file#./}"
        else
            SEARCH="$search" REPL="$replacement" \
                perl -i -pe 's/\Q$ENV{SEARCH}\E/$ENV{REPL}/g' "$file"
        fi
    done <<< "$files"
}

apply() {
    local label="$1" search="$2" replacement="$3"
    [[ "$search" == "$replacement" ]] && return 0
    log "$label: '$search' -> '$replacement'"
    replace_in_tree "$search" "$replacement"
}

[[ $DRY_RUN -eq 1 ]] && log "Dry run - no files will be modified."

apply "Project name"     "$OLD_NAME"         "$NEW_NAME"
apply "Product name"     "$OLD_PRODUCT"      "$NEW_PRODUCT"
apply "Company name"     "$OLD_COMPANY"      "$NEW_COMPANY"
apply "Bundle id"        "$OLD_BUNDLE_ID"    "$NEW_BUNDLE_ID"
apply "Plugin code"      "$OLD_CODE"         "$NEW_CODE"
apply "Manufacturer"     "$OLD_MANUFACTURER" "$NEW_MANUFACTURER"
apply "Description"      "$OLD_DESCRIPTION"  "$NEW_DESCRIPTION"
apply "URL"             "$OLD_URL"          "$NEW_URL"
apply "E-mail"          "$OLD_EMAIL"        "$NEW_EMAIL"

echo
if [[ $DRY_RUN -eq 1 ]]; then
    log "Dry run complete. Re-run without --dry-run to apply."
else
    log "Done. Next steps:"
    cat <<EOF
  1. Review the changes:        git diff
  2. Regenerate the project:    rm -rf build && just mac   (or: just ninja)
  3. Build and test:            just build && just test
  4. Replace assets/app-icon.png with your own and run: just icons
EOF
fi
