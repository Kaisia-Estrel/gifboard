{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      qtEnv =
        with pkgs.qt6;
        env "qt-custom-${qtbase.version}" [
          qtdeclarative
          pkgs.kdePackages.layer-shell-qt
        ];
    in
    {
      packages.${system}.default = pkgs.callPackage ./. { };
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [
          pkgs.libxkbcommon
          pkgs.libglvnd

          pkgs.binutils
          pkgs.clang-tools
          pkgs.cmake
          pkgs.clang
          qtEnv
          pkgs.rustPackages.cargo
          pkgs.rustPackages.clippy
          pkgs.rustPackages.rustc
          pkgs.rustPackages.rustfmt
          pkgs.lld
          pkgs.ninja
          pkgs.sccache
        ];

        nativeBuildInputs = [
          qtEnv
          pkgs.pkg-config
        ];

        LD_LIBRARY_PATH = "${pkgs.libxkbcommon}/lib:${qtEnv}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
        QMAKE = "${qtEnv}/bin/qmake";
        hardeningDisable = [ "fortify" ];
        RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
      };
    };
}
