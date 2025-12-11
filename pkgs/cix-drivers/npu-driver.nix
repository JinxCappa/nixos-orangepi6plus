{ lib
, stdenv
, kernel
, componentSource
}:

# ArmChina AIPU (NPU) kernel driver for Cix P1 SoC (Orange Pi 6 Plus)
# Builds: aipu.ko

stdenv.mkDerivation rec {
  pname = "cix-npu-driver";
  version = "5.11.0"; # From COMPASS_DRV_BTENVAR_KMD_VERSION in cix.conf

  src = componentSource;
  sourceRoot = "source/cix_opensource/npu/npu_driver";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Environment variables from cix.conf lines 161-167
  preBuild = ''
    export ARCH=arm64
    export KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    export CROSS_COMPILE=""

    # NPU driver configuration
    export COMPASS_DRV_BTENVAR_ARCH=arm64
    export COMPASS_DRV_BTENVAR_KMD_DIR=driver
    export COMPASS_DRV_BTENVAR_KMD_VERSION=${version}
    export COMPASS_DRV_BTENVAR_KPATH=$KDIR
    export BUILD_AIPU_VERSION_KMD=BUILD_ZHOUYI_V3
    export BUILD_TARGET_PLATFORM_KMD=BUILD_PLATFORM_SKY1
    export BUILD_NPU_DEVFREQ=y
  '';

  buildPhase = ''
    runHook preBuild

    # Copy header to a writable location for the build
    mkdir -p $TMPDIR/include/uapi/misc
    cp driver/armchina-npu/include/armchina_aipu.h $TMPDIR/include/uapi/misc/ 2>/dev/null || true

    # Clean first
    make -C driver \
      ARCH=$COMPASS_DRV_BTENVAR_ARCH \
      CROSS_COMPILE="" \
      clean || true

    # Build NPU driver
    make -C driver \
      ARCH=$COMPASS_DRV_BTENVAR_ARCH \
      CROSS_COMPILE="" \
      -j$NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
    mkdir -p $out/usr/src/aipu-${version}

    # Install kernel module
    cp driver/aipu.ko $out/lib/modules/${kernel.modDirVersion}/extra/

    # Install DKMS source for future kernel rebuilds
    make -C driver \
      ARCH=$COMPASS_DRV_BTENVAR_ARCH \
      CROSS_COMPILE="" \
      clean || true
    cp -r driver/* $out/usr/src/aipu-${version}/

    runHook postInstall
  '';

  meta = with lib; {
    description = "ArmChina AIPU (NPU) kernel driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
