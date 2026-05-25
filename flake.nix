{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      qtEnv =
        with pkgs.qt6;
        env "qt-custom-${qtbase.version}" [
          qtdeclarative
          qtbase
          pkgs.kdePackages.layer-shell-qt
          pkgs.kdePackages.qtimageformats
        ];
    in
    {
      packages.${system} = {
        gifboard = pkgs.callPackage ./. { };
        default = self.packages.${system}.gifboard;
      };
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.libxkbcommon
          pkgs.libglvnd
          pkgs.libxcb
          pkgs.libx11
          qtEnv
        ];

        nativeBuildInputs = [
          qtEnv
          pkgs.libx11.dev

          pkgs.pkg-config
          pkgs.binutils
          pkgs.clang-tools
          pkgs.cmake
          pkgs.clang
          pkgs.rustPackages.cargo
          pkgs.rustPackages.clippy
          pkgs.rustPackages.rustc
          pkgs.rustPackages.rustfmt
          pkgs.rust-analyzer
          pkgs.lld
          pkgs.ninja
          pkgs.sccache
        ];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
          pkgs.libxkbcommon
          pkgs.libxcb
          pkgs.libx11
          qtEnv
          pkgs.stdenv.cc.cc.lib
        ];
        QMAKE = "${qtEnv}/bin/qmake";
        hardeningDisable = [ "fortify" ];
        RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      };
    };
}
