{ lib
, stdenv
, fetchFromGitHub
, kernel
, bc
, ...
}:

stdenv.mkDerivation rec {
  pname = "rtl8812au";
  version = "unstable-2024-12-12";

  src = fetchFromGitHub {
    owner = "aircrack-ng";
    repo = "rtl8812au";
    rev = "c3fb89a2f7066f4bf4e4d9d85d84f9791f14c83e";
    hash = "sha256-AsgcViQEuQioeI9GDhUzmGQlc3La1cOIQtkSSPIEeGo=";
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
    install -D 88XXau.ko $out/lib/modules/${kernel.modDirVersion}/extra/88XXau.ko
    runHook postInstall
  '';

  meta = with lib; {
    description = "Realtek RTL8812AU/RTL8821AU WiFi driver";
    homepage = "https://github.com/aircrack-ng/rtl8812au";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
