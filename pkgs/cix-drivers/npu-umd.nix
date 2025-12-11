{ lib
, stdenv
, componentSource
, autoPatchelfHook
, glibc
, zlib
}:

# NPU/AIPU userspace driver for Cix P1 SoC
# Pre-built binaries from OEM's component repository

stdenv.mkDerivation rec {
  pname = "cix-npu-umd";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-npu-umd";

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

    # Copy library files
    if [ -d usr/lib ]; then
      mkdir -p $out/lib
      cp -r usr/lib/* $out/lib/
    fi

    # Copy share directory (may contain additional resources)
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
    description = "NPU/AIPU userspace driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
