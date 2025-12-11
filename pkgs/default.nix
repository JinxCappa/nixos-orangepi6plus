{ pkgs }:

let
  # ===================
  # SHARED SOURCES
  # ===================
  # Fetch the component repository once and share across all drivers
  #
  # HASH WORKFLOW:
  # 1. First build will fail with hash mismatch
  # 2. Copy the "got:" hash from the error message
  # 3. Replace lib.fakeHash below with the actual hash
  # 4. Alternatively, run: ./scripts/update-hashes.sh
  #
  # For reproducibility, pin to a specific commit instead of "main"
  componentSource = pkgs.fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "component_cix-next";
    rev = "ba3bac4167cd5f115f3eaf4717356d2b3cb923d5"; # main branch
    hash = "sha256-Wm39DqlTS+TPmB0snz1xeVYTgnjg40Th0VMvDA280Jg=";
  };

  # ===================
  # CUSTOM KERNEL
  # ===================
  linux-cix = pkgs.callPackage ./linux-cix { };

  # Kernel packages (modules, headers, etc.)
  linuxPackages-cix = pkgs.linuxPackagesFor linux-cix;

  # ===================
  # KERNEL MODULES
  # ===================
  # These build against the custom kernel using the shared component source
  cix-gpu-driver = pkgs.callPackage ./cix-drivers/gpu-driver.nix {
    kernel = linux-cix;
    inherit componentSource;
  };

  cix-npu-driver = pkgs.callPackage ./cix-drivers/npu-driver.nix {
    kernel = linux-cix;
    inherit componentSource;
  };

  cix-vpu-driver = pkgs.callPackage ./cix-drivers/vpu-driver.nix {
    kernel = linux-cix;
    inherit componentSource;
  };

  cix-isp-driver = pkgs.callPackage ./cix-drivers/isp-driver.nix {
    kernel = linux-cix;
    inherit componentSource;
  };

  # ===================
  # USERSPACE DRIVERS
  # ===================
  # Pre-built binaries extracted from component repository
  cix-gpu-umd = pkgs.callPackage ./cix-drivers/gpu-umd.nix {
    inherit componentSource;
  };

  cix-isp-umd = pkgs.callPackage ./cix-drivers/isp-umd.nix {
    inherit componentSource;
  };

  cix-vpu-umd = pkgs.callPackage ./cix-drivers/vpu-umd.nix {
    inherit componentSource;
  };

  cix-audio-dsp = pkgs.callPackage ./cix-drivers/audio-dsp.nix {
    inherit componentSource;
  };

  cix-noe-umd = pkgs.callPackage ./cix-drivers/noe-umd.nix {
    inherit componentSource;
  };

  # NOTE: These packages don't exist in the component_cix-next repo:
  # - cix-npu-umd (NPU userspace not available, only kernel driver)
  # - cix-dpu-ddk (not in repo)
  # - cix-hdcp2 (not in repo)

  # ===================
  # FIRMWARE
  # ===================
  cix-firmware = pkgs.callPackage ./cix-drivers/firmware.nix {
    inherit componentSource;
  };

  # ===================
  # REALTEK WIFI MODULES
  # ===================
  # Built out-of-tree from upstream GitHub sources
  # Usage: boot.extraModulePackages = [ pkgs.rtl8812au ];
  rtl8192eu = pkgs.callPackage ./rtl-wifi-modules/rtl8192eu.nix {
    kernel = linux-cix;
  };

  rtl8812au = pkgs.callPackage ./rtl-wifi-modules/rtl8812au.nix {
    kernel = linux-cix;
  };

  rtl8723ds = pkgs.callPackage ./rtl-wifi-modules/rtl8723ds.nix {
    kernel = linux-cix;
  };

  rtl8821cu = pkgs.callPackage ./rtl-wifi-modules/rtl8821cu.nix {
    kernel = linux-cix;
  };

  rtl88x2bu = pkgs.callPackage ./rtl-wifi-modules/rtl88x2bu.nix {
    kernel = linux-cix;
  };

in {
  inherit
    # Sources (for debugging/manual use)
    componentSource

    # Kernel
    linux-cix
    linuxPackages-cix

    # Kernel modules
    cix-gpu-driver
    cix-npu-driver
    cix-vpu-driver
    cix-isp-driver

    # Userspace drivers
    cix-gpu-umd
    cix-isp-umd
    cix-vpu-umd
    cix-audio-dsp
    cix-noe-umd

    # Firmware
    cix-firmware

    # Realtek WiFi modules (out-of-tree)
    rtl8192eu
    rtl8812au
    rtl8723ds
    rtl8821cu
    rtl88x2bu;
}
