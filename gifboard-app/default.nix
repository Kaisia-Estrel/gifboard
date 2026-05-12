{
  rustPlatform,
  pkg-config,
  kdePackages,
  qt6,
  libxkbcommon,
  cmake,
  libglvnd,
}:
let

  qtEnv = qt6.env "qt-custom-${qt6.qtbase.version}" [
    qt6.qtbase
    qt6.qtdeclarative
    kdePackages.layer-shell-qt
  ];
in
rustPlatform.buildRustPackage

  {
    pname = "gifboard";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [
      pkg-config
      cmake
      qtEnv
    ];

    buildInputs = [
      libxkbcommon
      qtEnv
      libglvnd
    ];

    cargoHash = "sha256-GWjuB/dutWqHhMg4EnfvSDhY84YSo5p5T3Z1Ee97Q2I=";

  }
