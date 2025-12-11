{ config, lib, pkgs, modulesPath, ... }:

{
  # Orange Pi 6 Plus hardware configuration

  # File systems - these will be adjusted by the image builder
  # For actual hardware, you may need to adjust based on your partition layout
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Swap (optional - you may want zram instead)
  # swapDevices = [
  #   { device = "/dev/disk/by-label/swap"; }
  # ];

  # Use zram for swap (better for flash storage)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # Hardware settings
  hardware = {
    # Enable all firmware
    enableAllFirmware = true;
    enableRedistributableFirmware = true;

    # Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Note: hardware.graphics is configured in orangepi6plus.nix
  # to include the Mali GPU drivers

  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil"; # or "ondemand", "performance"
  };
}
