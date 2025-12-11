{ config, lib, pkgs, ... }:

{
  # Orange Pi 6 Plus board-specific configuration
  # Cix P1 SoC - UEFI/ACPI boot
  #
  # NOTE: nixpkgs.hostPlatform is NOT set here to allow this module to be
  # imported into flakes that use readOnlyPkgs. The consuming flake should
  # set the platform via its pkgs configuration or hardware-configuration.nix.

  # ===================
  # BOOTLOADER (GRUB EFI)
  # ===================
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true; # Install to /EFI/BOOT/BOOTAA64.EFI
      device = "nodev"; # EFI, not MBR
      configurationLimit = 10;
    };

    efi = {
      canTouchEfiVariables = false; # Safe for removable media
    };

    timeout = 5;
  };

  # ===================
  # KERNEL
  # ===================
  boot.kernelPackages = pkgs.linuxPackagesFor pkgs.linux-cix;

  # Kernel command line parameters
  boot.kernelParams = [
    # Serial console (Cix P1 uses ttyAMA2)
    "console=ttyAMA2,115200n8"
    "console=tty1"

    # Early printk for debugging (uart2 = ttyAMA2 @ 0x040d0000)
    "earlycon=pl011,0x040d0000"

    # ACPI settings
    "acpi=force"

    # Framebuffer console - use DRM framebuffer (fb1) instead of efifb (fb0)
    # This prevents blank screen when DRM driver takes over from efifb
    "fbcon=map:1"
  ];

  # ===================
  # KERNEL MODULES
  # ===================

  # Disable x86-specific default modules (ata_piix, etc.)
  boot.initrd.includeDefaultModules = false;

  # Modules available in initrd for booting
  boot.initrd.availableKernelModules = [
    # USB storage (for SD card boot)
    "uas"
    "usb_storage"
    "xhci_pci"
    "usbhid"

    # MMC/SD card support (mmc_block is built-in)

    # NVMe (for NVMe boot - nvme is built-in)

    # Generic storage (sd_mod is built-in)
  ];

  # Module load order dependencies
  # Mali GPU requires these modules loaded first
  boot.extraModprobeConfig = ''
    softdep mali_kbase pre: memory_group_manager protected_memory_allocator
  '';

  # Modules to load at boot
  boot.kernelModules = [
    # From orangepi6plus.conf MODULES_CURRENT
    "armcb_isp_v4l2"
    "btusb"

    # Proprietary driver modules (order matters due to softdep above)
    "memory_group_manager"
    "protected_memory_allocator"
    "mali_kbase"
    "aipu"
    "amvx"
    # I2C support
    "i2c-dev"
  ];

  # Modules to blacklist (from overlays_cix_next/etc/modprobe.d/blacklist.conf)
  boot.blacklistedKernelModules = [
    "r8125"            # Realtek NIC - conflicts with built-in driver
    "pgdrv"            # Unknown/problematic driver
    "rtk_btusb"        # Realtek Bluetooth - use generic btusb instead
    "amdgpu"           # x86 AMD GPU - not applicable on ARM
    "armcb_isp"        # Old ISP driver - use armcb_isp_v4l2 instead
    "csi_dma"          # CSI camera DMA - conflicts with ISP v4l2
    "csi_mipi_dphy_hw" # CSI MIPI PHY - conflicts with ISP v4l2
    "csi_rcsu_hw"      # CSI RCSU - conflicts with ISP v4l2
  ];

  # Extra kernel module packages (out-of-tree drivers)
  boot.extraModulePackages = [
    pkgs.cix-gpu-driver
    pkgs.cix-npu-driver
    pkgs.cix-vpu-driver
    pkgs.cix-isp-driver
  ];

  # ===================
  # FIRMWARE
  # ===================
  hardware.firmware = [
    pkgs.cix-firmware
    pkgs.cix-audio-dsp
  ];

  # ===================
  # GRAPHICS (OpenGL ES)
  # ===================
  # Using hardware.graphics (nixos-unstable API)
  hardware.graphics = {
    enable = true;
    # Mali GPU userspace drivers for OpenGL ES
    extraPackages = [
      pkgs.cix-gpu-umd
    ];
  };

  # ===================
  # ENVIRONMENT
  # ===================

  # Environment variables for OpenGL ES (from cix_env.sh)
  environment.variables = {
    # KWin compositor - use OpenGL ES 2
    KWIN_COMPOSE = "O2ES";
    # Qt - use OpenGL ES 2
    QT_OPENGL = "es2";
    # GTK/GDK - use GLES
    GDK_GL = "gles";
    # GStreamer - use GLES2
    GST_GL_API = "gles2";
  };

  # ===================
  # SERIAL CONSOLE
  # ===================
  # NixOS automatically enables serial-getty from kernel params,
  # but we explicitly enable tty1 for HDMI console
  services.getty.autologinUser = lib.mkDefault null;

  # ===================
  # I2C / RTC SUPPORT
  # ===================

  # Hardware RTC (DS3231) on I2C bus
  # The kernel should auto-detect via ACPI, but if not, use this service
  # to manually instantiate the RTC device on I2C2
  systemd.services.rtc-ds3231 = {
    description = "Initialize DS3231 RTC on I2C2";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Find the I2C bus (usually i2c-2 for I2C2)
      for bus in /sys/class/i2c-adapter/i2c-*; do
        if [ -e "$bus" ]; then
          busnum=$(basename "$bus" | sed 's/i2c-//')
          # DS3231 is at address 0x68
          if [ ! -e "/sys/class/rtc/rtc1" ]; then
            echo ds3231 0x68 > "/sys/class/i2c-adapter/i2c-$busnum/new_device" 2>/dev/null || true
          fi
        fi
      done

      # Sync system clock from RTC if available
      if [ -e /dev/rtc1 ]; then
        ${pkgs.util-linux}/bin/hwclock --rtc=/dev/rtc1 --hctosys || true
      fi
    '';

    path = with pkgs; [ coreutils gnused util-linux ];
  };

  # Allow users in 'i2c' group to access I2C devices
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
    KERNEL=="ttyAMA[0-9]*", GROUP="dialout", MODE="0660"
  '';

  # Add i2c group
  users.groups.i2c = {};

  # ===================
  # FIRST BOOT SETUP
  # ===================
  # Automatically expand root partition to fill the disk on first boot
  systemd.services.expand-root = {
    description = "Expand root partition to fill disk";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];

    # Only run if marker file doesn't exist
    unitConfig.ConditionPathExists = "!/var/lib/expand-root-done";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      # Get root device (e.g., /dev/mmcblk0p2 -> /dev/mmcblk0)
      ROOT_PART=$(findmnt -n -o SOURCE /)
      ROOT_DISK="/dev/$(lsblk -no PKNAME "$ROOT_PART" | head -1)"
      PART_NUM=$(echo "$ROOT_PART" | grep -oE '[0-9]+$')

      echo "Root partition: $ROOT_PART"
      echo "Root disk: $ROOT_DISK"
      echo "Partition number: $PART_NUM"

      # Expand GPT to fill disk (moves backup GPT to end)
      echo "Expanding GPT table..."
      sgdisk -e "$ROOT_DISK" || true

      # Grow partition to fill available space
      echo "Growing partition..."
      growpart "$ROOT_DISK" "$PART_NUM" || true

      # Resize filesystem online
      echo "Resizing filesystem..."
      resize2fs "$ROOT_PART"

      # Mark as done
      mkdir -p /var/lib
      touch /var/lib/expand-root-done
      echo "Root partition expanded successfully"
    '';

    path = with pkgs; [ util-linux cloud-utils e2fsprogs gptfdisk gnugrep ];
  };
}
