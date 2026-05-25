{
  rustPlatform,
  pkg-config,
  kdePackages,
  qt6,
  libxkbcommon,
  cmake,
  libglvnd,
  binutils,
  clang-tools,
  clang,
  lld,
  lib,
  stdenv,
  makeWrapper,
  libxcb,
}:
let

  qtEnv = qt6.env "qt-custom-${qt6.qtbase.version}" [
    qt6.qtbase
    qt6.qtdeclarative
    kdePackages.layer-shell-qt
    kdePackages.qtimageformats
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
      binutils
      clang-tools
      clang
      lld
      libxcb
      makeWrapper
    ];

    buildInputs = [
      libxkbcommon
      qtEnv
      libglvnd
    ];

    cargoHash = "sha256-hVGTUNGi+PPfkWe955uUSxPO/MAloBadUhtjesPdSQI=";

    preCheck = ''
      export LD_LIBRARY_PATH="${
        lib.makeLibraryPath [
          qtEnv
          libxkbcommon
          libglvnd
          stdenv.cc.cc.lib
        ]
      }:$LD_LIBRARY_PATH"
    '';

    postInstall = ''
      wrapProgram $out/bin/gifboard \
        --prefix LD_LIBRARY_PATH : "${
          lib.makeLibraryPath [
            libxkbcommon
            qtEnv
            libglvnd
            stdenv.cc.cc.lib
          ]
        }"
    '';

    meta = {
      mainProgram = "gifboard";
    };
  }
