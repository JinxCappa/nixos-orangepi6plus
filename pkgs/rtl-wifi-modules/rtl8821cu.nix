{ lib
, stdenv
, fetchFromGitHub
, kernel
, bc
, ...
}:

stdenv.mkDerivation rec {
  pname = "rtl8821cu";
  version = "unstable-2024-09-13";

  src = fetchFromGitHub {
    owner = "morrownr";
    repo = "8821cu-20210916";
    rev = "3d1fcf4bc838542ceb03b0b4e9e40600720cf6ae";
    hash = "sha256-N22f4TOPyGIROcmkiUtPgOASVEbbSqsyOKMZTQpqjLs=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [ bc ];

  makeFlags = [
    "ARCH=arm64"
    "KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "KVER=${kernel.modDirVersion}"
  ];

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -D 8821cu.ko $out/lib/modules/${kernel.modDirVersion}/extra/8821cu.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Realtek RTL8821CU/RTL8811CU WiFi driver";
    homepage = "https://github.com/morrownr/8821cu-20210916";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
