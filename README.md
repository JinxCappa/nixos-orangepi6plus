# NixOS for Orange Pi 6 Plus

A Nix flake for building NixOS images for the Orange Pi 6 Plus SBC (Cix P1 SoC).

## Features

- **Custom Kernel**: Linux 6.6.89 with Cix P1 SoC support
- **GPU**: Mali GPU drivers (kernel module + userspace OpenGL ES)
- **NPU**: AIPU neural processing unit drivers
- **VPU**: Video processing unit for hardware video encode/decode
- **ISP**: Image signal processor for camera support
- **Audio DSP**: Hardware audio processing
- **Realtek WiFi**: Out-of-tree modules for RTL8192EU, RTL8812AU, RTL8723DS, RTL8821CU, RTL88x2BU
- **Auto-expand**: Root partition automatically expands on first boot
- **RTC Support**: DS3231 I2C RTC integration

## Hardware

- **Board**: Orange Pi 6 Plus
- **SoC**: Cix P1 (12-core ARM64)
- **Boot**: UEFI/ACPI with GRUB EFI
- **Serial Console**: `ttyAMA2` at 115200 baud

## Quick Start

```bash
# Build the image
nix build .#images.aarch64-linux.raw-efi

# Or use the helper script (creates dated filename)
./scripts/build-image.sh

# Flash to SD card
zstdcat result | sudo dd of=/dev/sdX bs=4M status=progress
```

## Prerequisites

1. **Nix with flakes enabled**:
   ```bash
   # In your /etc/nix/nix.conf or ~/.config/nix/nix.conf:
   experimental-features = nix-command flakes
   ```

2. **For cross-compilation from x86_64**, enable binfmt in your NixOS config:
   ```nix
   boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
   ```

3. **Proprietary driver sources** (see Setup section below)

## Setup: Obtaining Source Hashes

Before building, you need to obtain the correct hashes for the source repositories.

### Automatic (Recommended)

Run the helper script:
```bash
./scripts/update-hashes.sh
```

This will fetch the sources and display the hashes to update in the Nix files.

### Manual

1. **First build attempt** - Run the build, it will fail with a hash mismatch:
   ```bash
   nix build .#packages.aarch64-linux.linux-cix 2>&1 | grep "got:"
   ```

2. **Update the hash** - Copy the hash from "got:" and update the file:
   - Kernel: `pkgs/linux-cix/default.nix`
   - Components: `pkgs/default.nix`

3. **Repeat** for each source that needs updating.

## Setup: Proprietary Sources

The proprietary driver binaries are fetched from the OEM's component repository.
If Gitee is slow or blocked in your region:

### Option 1: Run OEM Build First

1. Run the OEM's build system once:
   ```bash
   cd orangepi-build
   sudo ./build.sh
   ```

2. After the build, the sources will be in:
   ```
   orangepi-build/external/cache/sources/component_cix-next/
   ```

### Option 2: Manual Clone

```bash
# Kernel source
git clone --depth 1 -b orange-pi-6.6-cix \
  https://gitee.com/orangepi-xunlong/orange-pi-6.6-cix.git

# Component repository (drivers)
git clone https://gitee.com/orangepi-xunlong/component_cix-next.git
```

Then update the Nix files to use local paths instead of fetchgit.

## Building

### Build the Bootable Image

```bash
# Build the raw EFI image (GPT + ESP + root partition)
# This method works on any system (no KVM required)
nix build .#images.aarch64-linux.raw-efi

# Alternative: VM-based build (requires functional KVM)
nix build .#images.aarch64-linux.raw-efi-vm

# Result will be in ./result/
```

### Build Individual Components

```bash
# Build just the kernel
nix build .#packages.aarch64-linux.linux-cix

# Build a specific driver
nix build .#packages.aarch64-linux.cix-gpu-driver

# Build Realtek WiFi modules
nix build .#packages.aarch64-linux.rtl8812au
```

### Enter Development Shell

```bash
# On aarch64-linux
nix develop

# On x86_64-linux (for cross-compilation setup)
nix develop .#devShells.x86_64-linux.default

# On macOS (requires remote Linux builder)
nix develop .#devShells.aarch64-darwin.default
nix develop .#devShells.x86_64-darwin.default
```

## Flashing

### To SD Card

```bash
# Find your SD card device (e.g., /dev/sdb)
lsblk

# Flash the image (WARNING: this will erase the device!)
sudo dd if=result/nixos-*.img of=/dev/sdX bs=4M status=progress
sync
```

### To NVMe (from running system)

Boot from SD card first, then flash to NVMe:

```bash
sudo dd if=/path/to/nixos.img of=/dev/nvme0n1 bs=4M status=progress
sync
```

## First Boot

1. Connect serial console: `ttyAMA2` at 115200 baud
2. Default credentials:
   - Username: `orangepi`
   - Password: `orangepi`
   - Root password: `orangepi`
3. **Change passwords immediately!**
   ```bash
   passwd
   sudo passwd root
   ```

## Testing Drivers

```bash
# Check loaded kernel modules
lsmod | grep -E "mali|aipu|amvx|armcb"

# Test GPU
glxinfo | head -20  # or es2_info for GLES

# Test ISP daemon
systemctl status isp-daemon

# List video devices
v4l2-ctl --list-devices
```

## Directory Structure

```
.
├── flake.nix                 # Main flake definition
├── nixos/
│   ├── configuration.nix     # Main NixOS config
│   ├── hardware-configuration.nix
│   ├── lib/
│   │   └── make-efi-image.nix  # Custom image builder (no KVM needed)
│   └── modules/
│       ├── orangepi6plus.nix # Board-specific settings
│       └── cix-drivers.nix   # Driver services
├── pkgs/
│   ├── default.nix           # Package index
│   ├── linux-cix/            # Custom kernel
│   │   ├── default.nix
│   │   ├── config            # Kernel config (from OEM BSP)
│   │   └── patches/          # Kernel patches (GCC 14 fixes, etc.)
│   ├── cix-drivers/          # Driver packages
│   │   ├── gpu-driver.nix    # Mali GPU kernel module
│   │   ├── gpu-umd.nix       # Mali GPU userspace
│   │   ├── npu-driver.nix    # AIPU kernel module
│   │   ├── npu-umd.nix       # AIPU userspace
│   │   ├── vpu-driver.nix    # VPU kernel module
│   │   ├── vpu-umd.nix       # VPU userspace
│   │   ├── isp-driver.nix    # ISP kernel module
│   │   ├── isp-umd.nix       # ISP userspace
│   │   ├── dpu-ddk.nix       # Display DDK
│   │   ├── audio-dsp.nix     # Audio DSP firmware
│   │   ├── hdcp2.nix         # HDCP 2.x
│   │   ├── noe-umd.nix       # NPU optimization engine
│   │   └── firmware.nix      # Firmware blobs
│   └── rtl-wifi-modules/     # Realtek WiFi drivers
│       ├── default.nix
│       ├── rtl8192eu.nix
│       ├── rtl8723ds.nix
│       ├── rtl8812au.nix
│       ├── rtl8821cu.nix
│       └── rtl88x2bu.nix
└── scripts/
    ├── build-image.sh        # Build helper (creates dated image)
    ├── extract-proprietary.sh # Extract drivers from OEM build
    └── update-hashes.sh      # Update Nix source hashes
```

## Customization

### Change Default User

Edit `nixos/configuration.nix`:

```nix
users.users.myuser = {
  isNormalUser = true;
  extraGroups = [ "wheel" "video" "audio" ];
  initialPassword = "changeme";
};
```

### Enable Desktop Environment

Add to your configuration:

```nix
services.xserver = {
  enable = true;
  displayManager.gdm.enable = true;
  desktopManager.gnome.enable = true;
};
```

### Add WiFi Support

```nix
networking.wireless.enable = true;
# Or use NetworkManager:
networking.networkmanager.enable = true;
```

## Troubleshooting

### Source Hash Mismatch

After first build attempt, update the hash:

```bash
# Run the helper script
./scripts/update-hashes.sh

# Or manually get the hash from the error
nix build .#packages.aarch64-linux.linux-cix 2>&1 | grep "got:"
```

### Serial Console Not Working

- Check baud rate: 115200
- Check cable connection (TX/RX/GND)
- Ensure `console=ttyAMA2,115200n8` is in kernel params

### Drivers Not Loading

1. Check dmesg: `dmesg | grep -i mali`
2. Verify modules exist: `ls /run/current-system/kernel-modules/lib/modules/*/extra/`
3. Try manual load: `sudo modprobe mali_kbase`
4. Check dependencies: Mali requires `memory_group_manager` and `protected_memory_allocator` first

### Gitee Repository Access Issues

If Gitee is slow or blocked:
1. Use a VPN
2. Clone manually and use local paths
3. Mirror to GitHub/GitLab

## License

- Nix expressions: MIT
- Linux kernel: GPL-2.0
- Proprietary drivers: Vendor license (unfree)

## References

- [Orange Pi 6 Plus](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-6-Plus.html)
- [OEM Build Repository](https://gitee.com/orangepi-xunlong/orangepi-build)
- [Kernel Source](https://gitee.com/orangepi-xunlong/orange-pi-6.6-cix)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [nixos-generators](https://github.com/nix-community/nixos-generators)
