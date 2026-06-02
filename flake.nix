{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    crane.url = "github:ipetkov/crane";

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      crane,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:

      let
        pkgs = nixpkgs.legacyPackages.${system};
        inherit (pkgs) lib;
        qtEnv =
          with pkgs.qt6;
          env "qt-custom-${qtbase.version}" [
            qtdeclarative
            qtbase
            pkgs.kdePackages.layer-shell-qt
            pkgs.kdePackages.qtimageformats
          ];
        gitWrapper = pkgs.writeShellScriptBin "git" ''
          #!/usr/bin/env bash

          GIT="${pkgs.git}/bin/git"
          if [[ -t 0 || -p /dev/stdin ]]; then
            GIFBOARD_DIR="$($GIT rev-parse --show-toplevel)"
            function check_untracked_age() {
              local untracked_file="$1"
              local tracked_file="$2"
              if [[ -e "$untracked_file" ]]; then
                local untracked_age="$(stat -c %Y "$untracked_file")"
                local tracked_age="$(stat -c %Y "$tracked_file")"
                if (( $untracked_age > $tracked_age )); then
                  echo -e "\x1b[31mWarning: Untracked $untracked_file is newer than tracked $tracked_file\x1b[0m" >&2
                fi
              fi
            }

            if [[ -e "$GIFBOARD_DIR/untracked" ]]; then
              check_untracked_age "$GIFBOARD_DIR/untracked/main.qml" "$GIFBOARD_DIR/gifboard-qml/qml/main.qml"
            fi
          fi

          exec "$GIT" "$@"
        '';

        craneLib = crane.mkLib pkgs;
        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;

          nativeBuildInputs = with pkgs; [
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

          buildInputs = with pkgs; [
            libxkbcommon
            qtEnv
            libxcb
            libglvnd
            libx11
          ];
        };

        src = lib.cleanSource ./.;
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        individualCrateArgs = commonArgs // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml { inherit src; }) version;
        };

        gifboard = craneLib.buildPackage (
          individualCrateArgs
          // {
            pname = "gifboard";
            src = lib.cleanSource ./.;

            preCheck = ''
              export LD_LIBRARY_PATH="${
                with pkgs;
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
                  with pkgs;
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
        );
      in
      {
        packages.default = gifboard;
        apps.default = flake-utils.lib.mkApp {
          drv = gifboard;
        };

        devShells.default = craneLib.devShell {

          QMAKE = "${qtEnv}/bin/qmake";
          hardeningDisable = [ "fortify" ];
          RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";

          LD_LIBRARY_PATH = lib.makeLibraryPath [
            pkgs.stdenv.cc.cc.lib
            qtEnv
            pkgs.libxkbcommon
            pkgs.libglvnd
            pkgs.libxcb
          ];

          packages = [
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
            pkgs.xdpyinfo
            pkgs.dwm
            gitWrapper
          ];

          inherit (commonArgs) buildInputs nativeBuildInputs;
        };
      }
    );
}
