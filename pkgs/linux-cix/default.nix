{ lib
, fetchgit
, buildLinux
, linuxManualConfig
, ... } @ args:

# Orange Pi 6 Plus kernel (Cix P1 SoC)
# Source: https://gitee.com/orangepi-xunlong/orange-pi-6.6-cix.git
# Branch: orange-pi-6.6-cix
#
# HASH WORKFLOW:
# 1. First build will fail with hash mismatch
# 2. Copy the "got:" hash from the error message
# 3. Replace lib.fakeHash below with the actual hash
# 4. Alternatively, run: ./scripts/update-hashes.sh

linuxManualConfig rec {
  version = "6.6.89";
  modDirVersion = version;

  # Kernel source from OEM's Gitee repository
  # NOTE: You may need to clone this manually if Gitee is slow/blocked:
  #   git clone --depth 1 -b orange-pi-6.6-cix https://gitee.com/orangepi-xunlong/orange-pi-6.6-cix.git
  #   Then use: src = /path/to/local/clone;
  src = fetchgit {
    url = "https://gitee.com/orangepi-xunlong/orange-pi-6.6-cix.git";
    rev = "a77129b7c8e32ab133665499e981a1137988ecba"; # orange-pi-6.6-cix branch
    hash = "sha256-4vsh3qmAU5uCW1soU5q/2D+rgxsfLhJO5E9+X6vzGN0=";
    fetchSubmodules = false;
  };

  # Kernel configuration from OEM's BSP
  # Source: orangepi-build/external/config/kernel/linux-6.6-cix-p1-next.config
  configfile = ./config;

  # Allow building with any compatible GCC (OEM requires > 12.0)
  # stdenv handles this automatically in NixOS

  extraMeta = {
    branch = "6.6";
    platforms = [ "aarch64-linux" ];
    description = "Linux kernel for Orange Pi 6 Plus (Cix P1 SoC)";
    maintainers = [ ];
    # Note: Kernel is GPL, but some Cix-specific patches may have different licensing
    license = lib.licenses.gpl2Only;
  };

  # Kernel build configuration
  extraMakeFlags = [
    "ARCH=arm64"
  ];

  # Additional kernel patches
  kernelPatches = [
    # Fix GCC 14 compilation error in fwnode_regulator.c
    {
      name = "fix-fwnode-regulator-gcc14";
      patch = ./patches/fix-fwnode-regulator-gcc14.patch;
    }
    # Copy MNTN headers to include/linux/soc/cix/ for out-of-tree module builds
    # The kernel Makefile adds drivers/soc/cix/ap/platform/sky1/ to include path,
    # but this isn't preserved when building out-of-tree modules like the ISP driver
    {
      name = "copy-mntn-headers-to-include";
      patch = ./patches/copy-mntn-headers-to-include.patch;
    }
    # Note: Realtek WiFi drivers are built out-of-tree as separate modules
    # See pkgs/rtl-wifi-modules/ for rtl8192eu, rtl8812au, rtl8723ds, rtl8821cu, rtl88x2bu
  ];

  # Features to enable
  features = {
    # Enable these standard features
    ia32Emulation = false; # ARM64, not x86
    debug = false;
  };
}
