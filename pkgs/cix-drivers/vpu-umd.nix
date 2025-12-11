{ lib
, stdenv
, componentSource
, autoPatchelfHook
, glibc
, zlib
}:

# VPU (Video Processing Unit) userspace driver for Cix P1 SoC
# Pre-built binaries from OEM's component repository
# Note: Firmware is handled separately in firmware.nix

stdenv.mkDerivation rec {
  pname = "cix-vpu-umd";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-vpu-umd";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    zlib
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    # Copy library files (excluding firmware which goes to firmware.nix)
    if [ -d usr/lib ]; then
      mkdir -p $out/lib
      # Copy libs but not firmware
      find usr/lib -maxdepth 1 -type f -name "*.so*" -exec cp {} $out/lib/ \; 2>/dev/null || true
      # Copy subdirectories except firmware
      for dir in usr/lib/*/; do
        dirname=$(basename "$dir")
        if [ "$dirname" != "firmware" ]; then
          cp -r "$dir" $out/lib/
        fi
      done
    fi

    # Copy share directory
    if [ -d usr/share ]; then
      mkdir -p $out/share
      cp -r usr/share/* $out/share/
    fi

    # Copy any bin files
    if [ -d usr/bin ]; then
      mkdir -p $out/bin
      cp -r usr/bin/* $out/bin/
    fi

    runHook postInstall
  '';

  autoPatchelfIgnoreMissingDeps = true;

  meta = with lib; {
    description = "VPU userspace driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
