# Realtek WiFi driver modules for out-of-tree building
#
# These drivers are built separately from the kernel because:
# 1. They were designed for standalone out-of-tree builds
# 2. NixOS's kernel build (using O=) breaks their Makefile path assumptions
# 3. Building them out-of-tree avoids patching and uses upstream sources
#
# Usage in NixOS configuration:
#   boot.extraModulePackages = [ pkgs.rtl8812au ];
#
# Or to include multiple:
#   boot.extraModulePackages = with pkgs; [ rtl8812au rtl8821cu ];

{ callPackage, kernel }:

{
  rtl8192eu = callPackage ./rtl8192eu.nix { inherit kernel; };
  rtl8812au = callPackage ./rtl8812au.nix { inherit kernel; };
  rtl8723ds = callPackage ./rtl8723ds.nix { inherit kernel; };
  rtl8821cu = callPackage ./rtl8821cu.nix { inherit kernel; };
  rtl88x2bu = callPackage ./rtl88x2bu.nix { inherit kernel; };
}
