#!/usr/bin/env bash
#
# Extract proprietary driver sources from OEM's BSP
# Run this after the OEM build has completed at least once
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BSP_ROOT="${PROJECT_ROOT}/orangepi-build"

# Source directories in OEM's BSP
COMPONENT_SRC="${BSP_ROOT}/external/cache/sources/component_cix-next"
PROPRIETARY_DEBS="${COMPONENT_SRC}/cix_proprietary/cix_proprietary-debs"

# Destination directory
DEST="${PROJECT_ROOT}/pkgs/cix-drivers/sources"

echo "=== Orange Pi 6 Plus Proprietary Driver Extractor ==="
echo ""
echo "BSP Root: ${BSP_ROOT}"
echo "Component Source: ${COMPONENT_SRC}"
echo "Destination: ${DEST}"
echo ""

# Check if BSP exists
if [[ ! -d "${BSP_ROOT}" ]]; then
    echo "ERROR: BSP directory not found: ${BSP_ROOT}"
    echo "Please clone the OEM's build repository first."
    exit 1
fi

# Check if component sources exist
if [[ ! -d "${COMPONENT_SRC}" ]]; then
    echo "ERROR: Component sources not found: ${COMPONENT_SRC}"
    echo ""
    echo "You need to run the OEM build first to download sources:"
    echo "  cd ${BSP_ROOT}"
    echo "  sudo ./build.sh"
    echo ""
    echo "Or manually clone the component repository:"
    echo "  git clone https://gitee.com/orangepi-xunlong/component_cix-next.git"
    exit 1
fi

# Create destination directory
mkdir -p "${DEST}"

echo "Extracting proprietary userspace drivers..."

# List of proprietary packages to extract
PACKAGES=(
    "cix-gpu-umd"
    "cix-npu-umd"
    "cix-isp-umd"
    "cix-dpu-ddk"
    "cix-audio-dsp"
    "cix-hdcp2"
    "cix-noe-umd"
)

for pkg in "${PACKAGES[@]}"; do
    echo "  - ${pkg}"
    pkg_dir="${PROPRIETARY_DEBS}/${pkg}"
    dest_dir="${DEST}/${pkg}"

    if [[ -d "${pkg_dir}" ]]; then
        rm -rf "${dest_dir}"
        mkdir -p "${dest_dir}"
        cp -r "${pkg_dir}"/* "${dest_dir}/"
        echo "    Copied from: ${pkg_dir}"
    else
        echo "    WARNING: Not found at ${pkg_dir}"
    fi
done

# Extract firmware
echo ""
echo "Extracting firmware..."
FIRMWARE_DEST="${DEST}/cix-firmware"
mkdir -p "${FIRMWARE_DEST}"

# VPU firmware is typically in cix-vpu-umd
if [[ -d "${PROPRIETARY_DEBS}/cix-vpu-umd/usr/lib/firmware" ]]; then
    cp -r "${PROPRIETARY_DEBS}/cix-vpu-umd/usr/lib/firmware"/* "${FIRMWARE_DEST}/"
    echo "  - VPU firmware copied"
fi

# Audio firmware may be in cix-audio-dsp
if [[ -d "${PROPRIETARY_DEBS}/cix-audio-dsp/lib/firmware" ]]; then
    cp -r "${PROPRIETARY_DEBS}/cix-audio-dsp/lib/firmware"/* "${FIRMWARE_DEST}/"
    echo "  - Audio firmware copied"
fi

echo ""
echo "=== Extraction Complete ==="
echo ""
echo "Extracted packages:"
ls -la "${DEST}/"
echo ""
echo "Next steps:"
echo "1. Update the source hashes in pkgs/cix-drivers/*.nix"
echo "2. Build the flake: nix build .#images.aarch64-linux.raw-efi"
