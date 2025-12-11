{ lib
, stdenv
, componentSource
, autoPatchelfHook
, libdrm
, wayland
, libGL
, xorg
, zlib
, glibc
}:

# Mali GPU userspace driver (OpenGL ES, Vulkan) for Cix P1 SoC
# Pre-built binaries from OEM's component repository

stdenv.mkDerivation rec {
  pname = "cix-gpu-umd";
  version = "1.0.0";

  src = componentSource;

  # The proprietary binaries are in cix_proprietary/cix_proprietary-debs/
  sourceRoot = "source/cix_proprietary/cix_proprietary-debs/cix-gpu-umd";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    libdrm
    wayland
    libGL
    xorg.libX11
    xorg.libXext
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

  # Don't fail if some libraries can't be patched (may need runtime deps)
  autoPatchelfIgnoreMissingDeps = true;

  meta = with lib; {
    description = "Mali GPU userspace driver for Cix P1 SoC (OpenGL ES, Vulkan)";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
