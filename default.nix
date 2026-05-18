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
      makeWrapper
    ];

    buildInputs = [
      libxkbcommon
      qtEnv
      libglvnd
    ];

    cargoHash = "sha256-bu+amylEZYvv+7g1ty70YZTUt9bpZM3JigtBz4mg4oA=";

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
  }
