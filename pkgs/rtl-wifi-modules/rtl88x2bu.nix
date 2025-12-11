{ lib
, stdenv
, fetchFromGitHub
, kernel
, bc
, ...
}:

stdenv.mkDerivation rec {
  pname = "rtl88x2bu";
  version = "unstable-2024-12-12";

  src = fetchFromGitHub {
    owner = "morrownr";
    repo = "88x2bu-20210702";
    rev = "fe48647496798cac77976e310ee95da000b436c9";
    hash = "sha256-h20vwCgLOiNh0LN3MGwPl3F/PSWGc2XS4t1sdeFAOko=";
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
    install -D 88x2bu.ko $out/lib/modules/${kernel.modDirVersion}/extra/88x2bu.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Realtek RTL88x2BU WiFi driver";
    homepage = "https://github.com/morrownr/88x2bu-20210702";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
