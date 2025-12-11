{ lib
, stdenv
, kernel
, componentSource
}:

# Mali GPU kernel driver for Cix P1 SoC (Orange Pi 6 Plus)
# Builds: mali_kbase.ko, memory_group_manager.ko, protected_memory_allocator.ko

stdenv.mkDerivation rec {
  pname = "cix-gpu-driver";
  version = "1.0.0";

  src = componentSource;
  sourceRoot = "source/cix_opensource/gpu";

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Environment variables from cix.conf lines 192-197
  preBuild = ''
    export ARCH=arm64
    export KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    export CROSS_COMPILE=""

    # Mali driver configuration
    export CONFIG_MALI_BASE_MODULES=y
    export CONFIG_MALI_MEMORY_GROUP_MANAGER=y
    export CONFIG_MALI_PROTECTED_MEMORY_ALLOCATOR=y
    export CONFIG_MALI_PLATFORM_NAME="sky1"
    export CONFIG_MALI_CSF_SUPPORT=y
    export CONFIG_MALI_CIX_POWER_MODEL=y
  '';

  buildPhase = ''
    runHook preBuild

    # Clean first
    bash ./clean.sh 2>/dev/null || true

    # Build base drivers (memory_group_manager, protected_memory_allocator)
    make -C gpu_kernel/drivers/base/arm/ \
      ARCH=arm64 \
      KDIR=$KDIR \
      -j$NIX_BUILD_CORES

    # Build main GPU driver (mali_kbase)
    make -C gpu_kernel/drivers/gpu/arm/ \
      ARCH=arm64 \
      KDIR=$KDIR \
      -j$NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra

    # Install kernel modules
    cp gpu_kernel/drivers/base/arm/memory_group_manager/memory_group_manager.ko \
       $out/lib/modules/${kernel.modDirVersion}/extra/
    cp gpu_kernel/drivers/base/arm/protected_memory_allocator/protected_memory_allocator.ko \
       $out/lib/modules/${kernel.modDirVersion}/extra/
    cp gpu_kernel/drivers/gpu/arm/midgard/mali_kbase.ko \
       $out/lib/modules/${kernel.modDirVersion}/extra/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Mali GPU kernel driver for Cix P1 SoC";
    homepage = "https://gitee.com/orangepi-xunlong";
    license = licenses.unfree;
    platforms = [ "aarch64-linux" ];
  };
}
