{ lib
, stdenv
, fetchFromGitHub
, kernel
, bc
, ...
}:

stdenv.mkDerivation rec {
  pname = "rtl8723ds";
  version = "unstable-2024-06-13";

  src = fetchFromGitHub {
    owner = "lwfinger";
    repo = "rtl8723ds";
    rev = "52e593e8c889b68ba58bd51cbdbcad7fe71362e4";
    hash = "sha256-SszvDuWN9opkXyVQAOLjnNtPp93qrKgnGvzK0y7Y9b0=";
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
    install -D 8723ds.ko $out/lib/modules/${kernel.modDirVersion}/extra/8723ds.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Realtek RTL8723DS WiFi/Bluetooth SDIO driver";
    homepage = "https://github.com/lwfinger/rtl8723ds";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
