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
  libx11,
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
      libxcb
      libglvnd
      libx11
    ];

    cargoHash = "sha256-wEx178Puv1JgyXX/quVlMKvJ+diNKOODEN5HA+R0mJM=";

    preCheck = ''
      export LD_LIBRARY_PATH="${
        lib.makeLibraryPath [
          qtEnv
          libxkbcommon
          libglvnd
          libxcb
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
            libxcb
            stdenv.cc.cc.lib
          ]
        }"
    '';

    meta = {
      mainProgram = "gifboard";
    };
  }
