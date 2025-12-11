{ lib
, stdenv
, kernel
, componentSource
, scons
, python3
}:

# VPU (Video Processing Unit) kernel driver for Cix P1 SoC (Orange Pi 6 Plus)
# Builds: amvx.ko
# NOTE: Uses scons build system instead of make

stdenv.mkDerivation rec {
  pname = "cix-vpu-driver";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_opensource/vpu/vpu_driver";

  nativeBuildInputs = [
    scons
    python3
  ] ++ kernel.moduleBuildDependencies;

  preBuild = ''
    export ARCH=arm64
    export KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    export CROSS_COMPILE=""
  '';

  buildPhase = ''
    runHook preBuild

    # Clean first
    bash ./clean.sh 2>/dev/null || true

    # Build VPU driver using scons
    scons target=linux -j$NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    mkdir -p $out/share/cix/include

    # Install kernel module
    # Note: scons builds to aarch64-unknown-linux-gnu (Nix triplet), not aarch64-none-linux-gnu
    cp bin/aarch64-*/amvx.ko $out/lib/modules/${kernel.modDirVersion}/extra/

    # Install headers for userspace development
    cp include/aarch64-*/mvx-v4l2-controls.h $out/share/cix/include/

    runHook postInstall
  '';

  meta = with lib; {
    description = "VPU (Video Processing Unit) kernel driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
