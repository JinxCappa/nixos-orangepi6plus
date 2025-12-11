#!/usr/bin/env bash
set -euo pipefail

# Push built packages to Attic binary cache
#
# Required environment variables:
#   ATTIC_URL   - Attic server URL (e.g., https://cache.example.com)
#   ATTIC_CACHE - Cache name
#   ATTIC_TOKEN - Authentication token
#
# Usage:
#   export ATTIC_URL="https://cache.example.com"
#   export ATTIC_CACHE="orange"
#   export ATTIC_TOKEN="your-token"
#   ./scripts/push-cache.sh

# Validate required environment variables
: "${ATTIC_URL:?Error: ATTIC_URL environment variable is required}"
: "${ATTIC_CACHE:?Error: ATTIC_CACHE environment variable is required}"
: "${ATTIC_TOKEN:?Error: ATTIC_TOKEN environment variable is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

# Use attic from nixpkgs if not installed locally
attic() {
    if type -P attic &> /dev/null; then
        "$(type -P attic)" "$@"
    else
        nix run nixpkgs#attic-client -- "$@"
    fi
}

# All packages to build and push (excluding images)
# Note: linuxPackages-cix is a package set, not a derivation - use linux-cix instead
PACKAGES=(
    linux-cix
    cix-gpu-driver
    cix-npu-driver
    cix-vpu-driver
    cix-isp-driver
    cix-gpu-umd
    cix-isp-umd
    cix-vpu-umd
    cix-audio-dsp
    cix-noe-umd
    cix-firmware
    rtl8192eu
    rtl8812au
    rtl8723ds
    rtl8821cu
    rtl88x2bu
)

SYSTEM="aarch64-linux"

echo "=== Orange Pi 6 Plus Binary Cache Push ==="
echo "Attic URL:   $ATTIC_URL"
echo "Cache:       $ATTIC_CACHE"
echo "Packages:    ${#PACKAGES[@]}"
echo ""

# Configure Attic endpoint
echo "Configuring Attic..."
attic login --set-default local "$ATTIC_URL" "$ATTIC_TOKEN"

# Build and push each package
FAILED=()
SUCCEEDED=()

for pkg in "${PACKAGES[@]}"; do
    echo ""
    echo "=== Building $pkg ==="

    OUT_PATHS=""
    if OUT_PATHS=$(nix build "$FLAKE_DIR#packages.$SYSTEM.$pkg" --no-link --print-out-paths 2>/tmp/build-log-$$); then
        if [ -n "$OUT_PATHS" ]; then
            echo "Pushing $pkg to cache..."

            if attic push "$ATTIC_CACHE" $OUT_PATHS; then
                SUCCEEDED+=("$pkg")
                echo "✓ $pkg pushed successfully"
            else
                FAILED+=("$pkg (push failed)")
                echo "✗ $pkg push failed"
            fi
        else
            FAILED+=("$pkg (no output paths)")
            echo "✗ $pkg produced no output paths"
        fi
    else
        FAILED+=("$pkg (build failed)")
        echo "✗ $pkg build failed"
        cat /tmp/build-log-$$
    fi

    rm -f /tmp/build-log-$$
done

# Summary
echo ""
echo "=== Summary ==="
echo "Succeeded: ${#SUCCEEDED[@]}/${#PACKAGES[@]}"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo "Failed:"
    for f in "${FAILED[@]}"; do
        echo "  - $f"
    done
    exit 1
else
    echo "All packages built and pushed successfully!"
fi
