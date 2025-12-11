{ lib
, stdenv
, componentSource
, autoPatchelfHook
, glibc
, zlib
}:

# ISP (Image Signal Processor) userspace driver/daemon for Cix P1 SoC
# Contains isp_app daemon
# Pre-built binaries from OEM's component repository

stdenv.mkDerivation rec {
  pname = "cix-isp-umd";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-isp-umd";

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

    mkdir -p $out/bin
    mkdir -p $out/lib
    mkdir -p $out/share/cix/lib

    # Install isp_app binary
    if [ -f usr/bin/isp_app ]; then
      cp usr/bin/isp_app $out/bin/
    fi

    # Install libraries
    if [ -d usr/lib ]; then
      cp -r usr/lib/* $out/lib/
    fi

    if [ -d usr/share/cix/lib ]; then
      cp -r usr/share/cix/lib/* $out/share/cix/lib/
    fi

    if [ -d usr/share ]; then
      cp -r usr/share/* $out/share/ 2>/dev/null || true
    fi

    runHook postInstall
  '';

  autoPatchelfIgnoreMissingDeps = true;

  meta = with lib; {
    description = "ISP userspace driver and daemon for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
