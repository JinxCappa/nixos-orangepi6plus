{ lib
, stdenv
, componentSource
, autoPatchelfHook
, glibc
, zlib
, alsa-lib
}:

# Audio DSP firmware and libraries for Cix P1 SoC
# Pre-built binaries from OEM's component repository

stdenv.mkDerivation rec {
  pname = "cix-audio-dsp";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-audio-dsp";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    zlib
    alsa-lib
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    # Copy library files
    if [ -d usr/lib ]; then
      mkdir -p $out/lib
      cp -r usr/lib/* $out/lib/
    fi

    # Copy firmware files
    if [ -d lib/firmware ]; then
      mkdir -p $out/lib/firmware
      cp -r lib/firmware/* $out/lib/firmware/
    fi
    if [ -d usr/lib/firmware ]; then
      mkdir -p $out/lib/firmware
      cp -r usr/lib/firmware/* $out/lib/firmware/
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
    description = "Audio DSP firmware and libraries for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
