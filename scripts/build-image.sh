#!/usr/bin/env bash
set -euo pipefail

# Build the image
echo "Building NixOS image..."
nix build .#images.aarch64-linux.raw-efi

# Copy to a real file with date-based name
OUTPUT_NAME="orangepi6plus-nixos-$(date +%Y%m%d).img.zst"
echo "Copying to $OUTPUT_NAME..."
cp -L result "$OUTPUT_NAME"

# Clean up symlink
rm -f result

echo ""
echo "Image created: $OUTPUT_NAME"
echo ""
echo "To decompress: zstd -d $OUTPUT_NAME"
echo "To write to SD card: zstdcat $OUTPUT_NAME | sudo dd of=/dev/sdX bs=4M status=progress"
