{ config, lib, pkgs, ... }:

{
  # Cix P1 SoC proprietary driver services and configuration

  # ===================
  # ISP DAEMON SERVICE
  # ===================
  # Image Signal Processor daemon (from isp-daemon.service in BSP)
  systemd.services.isp-daemon = {
    description = "Cix ISP Daemon";
    after = [ "network.target" "multi-user.target" "systemd-modules-load.service" ];
    wants = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      # ISP libraries path (matches OEM config)
      LD_LIBRARY_PATH = "/usr/share/cix/lib";
    };

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.cix-isp-umd}/bin/isp_app -s 0";
      Restart = "always";
      RestartSec = 1;
      User = "root";
      # Rate limiting from OEM service
      StartLimitIntervalSec = 10;
      StartLimitBurst = 5;
    };
  };

  # ===================
  # UDEV RULES
  # ===================
  # Device permissions for GPU, NPU, VPU, ISP
  services.udev.extraRules = ''
    # Mali GPU
    KERNEL=="mali[0-9]*", MODE="0666", GROUP="video"
    KERNEL=="renderD*", MODE="0666", GROUP="render"

    # AIPU (NPU)
    KERNEL=="aipu", MODE="0666", GROUP="video"

    # VPU
    KERNEL=="amvx*", MODE="0666", GROUP="video"
    KERNEL=="video[0-9]*", MODE="0666", GROUP="video"

    # ISP
    KERNEL=="v4l-subdev*", MODE="0666", GROUP="video"
    KERNEL=="media*", MODE="0666", GROUP="video"

    # DRM
    SUBSYSTEM=="drm", MODE="0666", GROUP="video"
  '';

  # ===================
  # SYSTEM PACKAGES
  # ===================
  environment.systemPackages = [
    # Proprietary userspace drivers
    pkgs.cix-gpu-umd
    pkgs.cix-isp-umd
    pkgs.cix-vpu-umd
    pkgs.cix-audio-dsp
    pkgs.cix-noe-umd
  ];

  # ===================
  # LIBRARY PATHS
  # ===================
  environment.pathsToLink = [
    "/lib"
    "/share/cix"
  ];

  # ===================
  # GROUPS
  # ===================
  users.groups.video = { };
  users.groups.render = { };
  users.groups.input = { };
}
