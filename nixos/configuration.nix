{ config, lib, pkgs, inputs, cixPackages, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # System identification
  system.stateVersion = "26.05";
  networking.hostName = "orangepi6plus";

  # Allow unfree packages (required for proprietary drivers)
  nixpkgs.config.allowUnfree = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Basic system packages
  environment.systemPackages = with pkgs; [
    # System utilities
    vim
    wget
    curl
    htop
    git
    usbutils
    pciutils
    lshw

    # Networking
    iproute2
    ethtool

    # Hardware testing
    v4l-utils
    mesa-demos
  ];

  # Networking
  networking = {
    useDHCP = true;
    # Enable for WiFi
    # wireless.enable = true;
  };

  # SSH server
  services.openssh = {
    enable = true;
    settings = {
      # WARNING: Change to "prohibit-password" or "no" for production!
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # User configuration
  # WARNING: Change these passwords immediately after first boot!
  # Generate a hash with: mkpasswd -m sha-512
  users.users.orangepi = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "render" "input" "dialout" "i2c" ];
    # Default password: "orangepi" - CHANGE THIS!
    initialPassword = "orangepi";
  };

  # Root password - CHANGE THIS!
  # users.users.root.initialPassword = "orangepi";

  # Enable sudo
  security.sudo.wheelNeedsPassword = false; # For convenience during setup

  # Timezone (adjust as needed)
  time.timeZone = "UTC";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Sound (optional)
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;
  # Or use pipewire:
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   pulse.enable = true;
  # };
}
