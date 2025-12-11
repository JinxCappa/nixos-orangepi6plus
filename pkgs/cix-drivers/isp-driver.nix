{ lib
, stdenv
, kernel
, componentSource
}:

# ISP (Image Signal Processor) V4L2 kernel driver for Cix P1 SoC (Orange Pi 6 Plus)
# Builds: armcb_isp_v4l2.ko

stdenv.mkDerivation rec {
  pname = "cix-isp-driver-v4l2";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_opensource/isp/isp_driver";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  preBuild = ''
    export ARCH=arm64
    export PATH_ROOT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    export CROSS_COMPILE=""
  '';

  buildPhase = ''
    runHook preBuild

    # Clean first
    make ARCH=$ARCH CROSS_COMPILE="" PATH_ROOT=$PATH_ROOT clean || true

    # Build ISP driver
    make ARCH=$ARCH CROSS_COMPILE="" PATH_ROOT=$PATH_ROOT build -j$NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra

    # Install kernel module
    cp armcb_isp_v4l2.ko $out/lib/modules/${kernel.modDirVersion}/extra/

    runHook postInstall
  '';

  meta = with lib; {
    description = "ISP (Image Signal Processor) V4L2 kernel driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
