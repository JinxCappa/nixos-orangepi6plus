{ lib
, stdenv
, fetchFromGitHub
, kernel
, bc
, ...
}:

stdenv.mkDerivation rec {
  pname = "rtl8192eu";
  version = "unstable-2024-12-12";

  src = fetchFromGitHub {
    owner = "Mange";
    repo = "rtl8192eu-linux-driver";
    rev = "d53a23daeb1cb22f6688e418c31f90ffd53ab98f";
    hash = "sha256-MM0xOhvE69pIv5SsyJXTgLwrH8z0fCdDLQdvleg9q4g=";
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
    install -D 8192eu.ko $out/lib/modules/${kernel.modDirVersion}/extra/8192eu.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Realtek RTL8192EU WiFi driver";
    homepage = "https://github.com/Mange/rtl8192eu-linux-driver";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
