{ lib
, stdenv
, componentSource
}:

# VPU and other firmware for Cix P1 SoC
# Pre-built firmware files from OEM's component repository

stdenv.mkDerivation rec {
  pname = "cix-firmware";
  version = "1.0.0";

  src = componentSource;

  # VPU firmware is in cix-vpu-umd package
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-vpu-umd";

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/firmware

    # VPU firmware
    if [ -d usr/lib/firmware ]; then
      cp -r usr/lib/firmware/* $out/lib/firmware/
    fi

    # Check for firmware in lib/firmware as well
    if [ -d lib/firmware ]; then
      cp -r lib/firmware/* $out/lib/firmware/
    fi

    runHook postInstall
  '';

  meta = with lib; {
    description = "Firmware files for Cix P1 SoC (VPU, etc.)";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfreeRedistributableFirmware;
    platforms = [ "aarch64-linux" ];
  };
}
