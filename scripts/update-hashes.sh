#!/usr/bin/env bash
# Update source hashes for NixOS Orange Pi 6 Plus build
#
# This script automatically updates rev and hash values in nix files
# for all upstream sources (kernel, drivers, WiFi modules).
#
# Usage:
#   ./scripts/update-hashes.sh              # Update all sources
#   ./scripts/update-hashes.sh --dry-run    # Show what would change
#   ./scripts/update-hashes.sh --only kernel
#   ./scripts/update-hashes.sh --check      # Check for updates without modifying

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# CLI options
DRY_RUN=false
CHECK_ONLY=false
ONLY_SOURCE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#######################################
# Helper Functions
#######################################

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_dependencies() {
    local missing=()

    if ! command -v nix-prefetch-git &> /dev/null; then
        missing+=("nix-prefetch-git")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo "Install with: nix-shell -p ${missing[*]}"
        echo "Or enter dev shell: nix develop"
        exit 1
    fi
}

# Convert base32 nix hash to SRI format
convert_to_sri() {
    local hash="$1"
    # If already SRI format, return as-is
    if [[ "$hash" == sha256-* ]]; then
        echo "$hash"
    else
        nix hash convert --to sri --hash-algo sha256 "$hash" 2>/dev/null || echo "$hash"
    fi
}

# Fetch hash and rev from GitHub using nix-prefetch-git
# Args: owner repo ref [is_branch]
# Returns JSON with rev and hash
fetch_github() {
    local owner="$1"
    local repo="$2"
    local ref="$3"
    local is_branch="${4:-false}"

    if [ "$is_branch" = true ]; then
        nix-prefetch-git --quiet \
            --url "https://github.com/${owner}/${repo}.git" \
            --branch-name "$ref" 2>/dev/null
    else
        nix-prefetch-git --quiet \
            --url "https://github.com/${owner}/${repo}.git" \
            --rev "$ref" 2>/dev/null
    fi
}

# Fetch hash and rev from Gitee
fetch_gitee() {
    local owner="$1"
    local repo="$2"
    local ref="$3"
    local is_branch="${4:-false}"

    if [ "$is_branch" = true ]; then
        nix-prefetch-git --quiet \
            --url "https://gitee.com/${owner}/${repo}.git" \
            --branch-name "$ref" 2>/dev/null
    else
        nix-prefetch-git --quiet \
            --url "https://gitee.com/${owner}/${repo}.git" \
            --rev "$ref" 2>/dev/null
    fi
}

# Get latest version tag from GitHub repo (sorts semantically)
get_latest_github_tag() {
    local owner="$1"
    local repo="$2"

    # Get all tags, filter for clean version tags (v1.2.3 or 1.2.3, no suffixes like -DEV)
    # Then sort by version and get the highest
    curl -s "https://api.github.com/repos/${owner}/${repo}/tags" | \
        jq -r '.[].name' | \
        grep -E '^v?[0-9]+(\.[0-9]+)+$' | \
        sort -V | \
        tail -1
}

# Update rev and hash in a nix file
# Args: file old_rev new_rev old_hash new_hash
update_nix_file() {
    local file="$1"
    local old_rev="$2"
    local new_rev="$3"
    local old_hash="$4"
    local new_hash="$5"

    if [ "$DRY_RUN" = true ]; then
        echo "  Would update $file:"
        echo "    rev: $old_rev → $new_rev"
        echo "    hash: $old_hash → $new_hash"
        return
    fi

    # Escape special characters for sed
    local old_rev_escaped=$(printf '%s\n' "$old_rev" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local new_rev_escaped=$(printf '%s\n' "$new_rev" | sed 's/[&/\]/\\&/g')
    local old_hash_escaped=$(printf '%s\n' "$old_hash" | sed 's/[[\.*^$()+?{|]/\\&/g')
    local new_hash_escaped=$(printf '%s\n' "$new_hash" | sed 's/[&/\]/\\&/g')

    # Update rev
    sed -i.bak "s|$old_rev_escaped|$new_rev_escaped|g" "$file"
    # Update hash
    sed -i.bak "s|$old_hash_escaped|$new_hash_escaped|g" "$file"

    # Remove backup file
    rm -f "${file}.bak"
}

# Extract current rev from nix file
get_current_rev() {
    local file="$1"
    sed -n 's/.*rev\s*=\s*"\([^"]*\)".*/\1/p' "$file" | head -1
}

# Extract current version from nix file
get_current_version() {
    local file="$1"
    sed -n 's/.*version\s*=\s*"\([^"]*\)".*/\1/p' "$file" | head -1
}

# Extract current hash from nix file
get_current_hash() {
    local file="$1"
    sed -n 's/.*hash\s*=\s*"\([^"]*\)".*/\1/p' "$file" | head -1
}

# Check if rev field uses version variable (e.g., "v${version}")
rev_uses_version() {
    local file="$1"
    grep -q 'rev\s*=.*\${version}' "$file"
}

#######################################
# Source Update Functions
#######################################

update_kernel() {
    log_info "Checking kernel source..."
    local file="$REPO_ROOT/pkgs/linux-cix/default.nix"
    local owner="orangepi-xunlong"
    local repo="orange-pi-6.6-cix"
    local branch="orange-pi-6.6-cix"

    local current_rev=$(get_current_rev "$file")
    local current_hash=$(get_current_hash "$file")

    echo "  Repository: gitee.com/$owner/$repo"
    echo "  Branch: $branch"
    echo "  Current rev: $current_rev"

    local result
    if ! result=$(fetch_gitee "$owner" "$repo" "$branch" true 2>&1); then
        log_warning "Could not fetch kernel source (Gitee may be slow/blocked)"
        return 1
    fi

    local new_rev=$(echo "$result" | jq -r '.rev')
    local new_hash_base32=$(echo "$result" | jq -r '.sha256')
    local new_hash=$(convert_to_sri "$new_hash_base32")

    if [ "$current_rev" = "$new_rev" ]; then
        log_success "Kernel is up to date ($new_rev)"
        return 0
    fi

    if [ "$CHECK_ONLY" = true ]; then
        log_warning "Kernel has update available: $current_rev → $new_rev"
        return 0
    fi

    update_nix_file "$file" "$current_rev" "$new_rev" "$current_hash" "$new_hash"
    log_success "Updated kernel: $current_rev → $new_rev"
}

update_component() {
    log_info "Checking component source..."
    local file="$REPO_ROOT/pkgs/default.nix"
    local owner="orangepi-xunlong"
    local repo="component_cix-next"
    local branch="main"

    local current_rev=$(get_current_rev "$file")
    local current_hash=$(get_current_hash "$file")

    echo "  Repository: github.com/$owner/$repo"
    echo "  Branch: $branch"
    echo "  Current rev: $current_rev"

    local result
    if ! result=$(fetch_github "$owner" "$repo" "$branch" true 2>&1); then
        log_warning "Could not fetch component source"
        return 1
    fi

    local new_rev=$(echo "$result" | jq -r '.rev')
    local new_hash_base32=$(echo "$result" | jq -r '.sha256')
    local new_hash=$(convert_to_sri "$new_hash_base32")

    if [ "$current_rev" = "$new_rev" ]; then
        log_success "Component is up to date ($new_rev)"
        return 0
    fi

    if [ "$CHECK_ONLY" = true ]; then
        log_warning "Component has update available: $current_rev → $new_rev"
        return 0
    fi

    update_nix_file "$file" "$current_rev" "$new_rev" "$current_hash" "$new_hash"
    log_success "Updated component: $current_rev → $new_rev"
}

update_rtl_driver() {
    local name="$1"
    local owner="$2"
    local repo="$3"
    local ref="$4"
    local use_tags="$5"

    log_info "Checking $name..."
    local file="$REPO_ROOT/pkgs/rtl-wifi-modules/${name}.nix"

    local current_hash=$(get_current_hash "$file")
    local uses_version_rev=false
    local current_version=""
    local current_rev=""

    # Check if this file uses rev = "v${version}" pattern
    if rev_uses_version "$file"; then
        uses_version_rev=true
        current_version=$(get_current_version "$file")
        current_rev="v${current_version}"
        echo "  Uses version-based rev (v\${version})"
    else
        current_rev=$(get_current_rev "$file")
    fi

    echo "  Repository: github.com/$owner/$repo"

    local target_ref="$ref"
    local new_version=""
    local is_branch=true
    if [ "$use_tags" = true ]; then
        local latest_tag=$(get_latest_github_tag "$owner" "$repo")
        if [ -n "$latest_tag" ]; then
            target_ref="$latest_tag"
            is_branch=false
            # Extract version from tag (strip leading 'v' if present)
            new_version="${latest_tag#v}"
            echo "  Latest tag: $latest_tag"
        else
            echo "  Branch: $ref (no tags found)"
        fi
    else
        echo "  Branch: $ref"
    fi
    echo "  Current rev: $current_rev"

    local result
    if ! result=$(fetch_github "$owner" "$repo" "$target_ref" "$is_branch" 2>&1); then
        log_warning "Could not fetch $name source"
        return 1
    fi

    local new_rev=$(echo "$result" | jq -r '.rev')
    local new_hash_base32=$(echo "$result" | jq -r '.sha256')
    local new_hash=$(convert_to_sri "$new_hash_base32")

    # For version-based revs, compare versions; otherwise compare revs
    if [ "$uses_version_rev" = true ] && [ -n "$new_version" ]; then
        if [ "$current_version" = "$new_version" ]; then
            log_success "$name is up to date (v$new_version)"
            return 0
        fi

        if [ "$CHECK_ONLY" = true ]; then
            log_warning "$name has update available: v$current_version → v$new_version"
            return 0
        fi

        # Update version field instead of rev
        update_nix_file "$file" "$current_version" "$new_version" "$current_hash" "$new_hash"
        log_success "Updated $name: v$current_version → v$new_version"
    else
        if [ "$current_rev" = "$new_rev" ]; then
            log_success "$name is up to date ($new_rev)"
            return 0
        fi

        if [ "$CHECK_ONLY" = true ]; then
            log_warning "$name has update available: $current_rev → $new_rev"
            return 0
        fi

        update_nix_file "$file" "$current_rev" "$new_rev" "$current_hash" "$new_hash"
        log_success "Updated $name: $current_rev → $new_rev"
    fi
}

#######################################
# Main
#######################################

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Update source hashes for NixOS Orange Pi 6 Plus build.

Options:
    --dry-run       Show what would be updated without modifying files
    --check         Check for updates without modifying files
    --only SOURCE   Update only the specified source
    -h, --help      Show this help message

Sources:
    kernel          Orange Pi kernel from Gitee
    component       Cix driver components from GitHub
    rtl8192eu       Realtek RTL8192EU WiFi driver
    rtl8812au       Realtek RTL8812AU WiFi driver
    rtl8723ds       Realtek RTL8723DS WiFi driver
    rtl8821cu       Realtek RTL8821CU WiFi driver
    rtl88x2bu       Realtek RTL88x2BU WiFi driver
    wifi            All WiFi drivers

Examples:
    $(basename "$0")                    # Update all sources
    $(basename "$0") --dry-run          # Preview changes
    $(basename "$0") --check            # Check for available updates
    $(basename "$0") --only kernel      # Update only kernel
    $(basename "$0") --only wifi        # Update all WiFi drivers
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --only)
                ONLY_SOURCE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    echo "=== Orange Pi 6 Plus NixOS Hash Updater ==="
    echo ""

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN MODE - No files will be modified]"
        echo ""
    fi

    if [ "$CHECK_ONLY" = true ]; then
        echo "[CHECK MODE - Checking for available updates]"
        echo ""
    fi

    check_dependencies

    # Determine what to update
    local update_kernel=true
    local update_component=true
    local update_wifi=true

    if [ -n "$ONLY_SOURCE" ]; then
        update_kernel=false
        update_component=false
        update_wifi=false

        case "$ONLY_SOURCE" in
            kernel)
                update_kernel=true
                ;;
            component)
                update_component=true
                ;;
            wifi)
                update_wifi=true
                ;;
            rtl8192eu|rtl8812au|rtl8723ds|rtl8821cu|rtl88x2bu)
                # Individual WiFi driver handled below
                ;;
            *)
                log_error "Unknown source: $ONLY_SOURCE"
                usage
                exit 1
                ;;
        esac
    fi

    # Update sources
    if [ "$update_kernel" = true ]; then
        update_kernel || true
        echo ""
    fi

    if [ "$update_component" = true ]; then
        update_component || true
        echo ""
    fi

    if [ "$update_wifi" = true ]; then
        # RTL WiFi drivers
        # Format: name owner repo ref use_tags
        update_rtl_driver "rtl8192eu" "Mange" "rtl8192eu-linux-driver" "master" false || true
        echo ""
        update_rtl_driver "rtl8812au" "aircrack-ng" "rtl8812au" "master" false || true
        echo ""
        update_rtl_driver "rtl8723ds" "lwfinger" "rtl8723ds" "main" false || true
        echo ""
        update_rtl_driver "rtl8821cu" "morrownr" "8821cu-20210916" "main" false || true
        echo ""
        update_rtl_driver "rtl88x2bu" "morrownr" "88x2bu-20210702" "main" false || true
        echo ""
    elif [ -n "$ONLY_SOURCE" ]; then
        # Handle individual WiFi driver
        case "$ONLY_SOURCE" in
            rtl8192eu)
                update_rtl_driver "rtl8192eu" "Mange" "rtl8192eu-linux-driver" "master" false || true
                ;;
            rtl8812au)
                update_rtl_driver "rtl8812au" "aircrack-ng" "rtl8812au" "master" false || true
                ;;
            rtl8723ds)
                update_rtl_driver "rtl8723ds" "lwfinger" "rtl8723ds" "main" false || true
                ;;
            rtl8821cu)
                update_rtl_driver "rtl8821cu" "morrownr" "8821cu-20210916" "main" false || true
                ;;
            rtl88x2bu)
                update_rtl_driver "rtl88x2bu" "morrownr" "88x2bu-20210702" "main" false || true
                ;;
        esac
        echo ""
    fi

    echo "=== Done ==="

    if [ "$DRY_RUN" = false ] && [ "$CHECK_ONLY" = false ]; then
        echo ""
        echo "Next steps:"
        echo "  1. Review changes: git diff"
        echo "  2. Test build: nix build .#packages.aarch64-linux.linux-cix"
        echo "  3. Commit: git add -A && git commit -m 'chore: update source hashes'"
    fi
}

main "$@"
