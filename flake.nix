{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    fenix,
    crane,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        pkgs_aarch64 = pkgs.pkgsCross.aarch64-multiplatform-musl;
        pkgs_arm = import nixpkgs {
          inherit system;
          crossSystem.config = "armv7l-unknown-linux-musleabihf";
        };
        pkgs_amd64 = pkgs.pkgsCross.musl64;
        pkgs_windows = pkgs.pkgsCross.mingwW64;

        rustToolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-+9FmLhAOezBZCOziO0Qct1NOrfpjNsXxc/8I0c7BdKE=";
        };

        exampleDependency = builtins.fetchurl {
          url = "https://github.com/jibsen/parg/archive/refs/tags/v1.0.3.zip";
          sha256 = "sha256:072irh6fc4w2xc0nmj668i3v24w7pz4s5sk7g5zbcdrb659hfsz7";
        };

        src = ./.;

        nativeBuildInputs = with pkgs; [
          rustToolchain
          rustPlatform.bindgenHook
          just
          nushell
          p7zip
        ];

        commonArgs = {
          inherit src nativeBuildInputs;
          strictDeps = true;
          RUST_BACKTRACE = 1;

          preBuild = ''
            if [ -z "''${CRANE_BUILD_DEPS_ONLY:-}"]; then
              echo "Setting up downloads folder"
              mkdir -p _downloads
              cp ${exampleDependency} _downloads/parg-1.0.3.zip
              ${pkgs.just}/bin/just download_deps
              echo "Done setting up downloads folder"
            fi
          '';
        };

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        craneLib-aarch64 = (crane.mkLib pkgs_aarch64).overrideToolchain rustToolchain;
        craneLib-arm = (crane.mkLib pkgs_arm).overrideToolchain rustToolchain;
        craneLib-amd64 = (crane.mkLib pkgs_amd64).overrideToolchain rustToolchain;
        craneLib-windows = (crane.mkLib pkgs_windows).overrideToolchain rustToolchain;

        cargoArtifacts = craneLib.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs.rustPlatform.bindgenHook];});
        cargoArtifacts-aarch64 = craneLib-aarch64.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs_aarch64.rustPlatform.bindgenHook];});
        cargoArtifacts-arm = craneLib-arm.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs_arm.rustPlatform.bindgenHook];});
        cargoArtifacts-amd64 = craneLib-amd64.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs_amd64.rustPlatform.bindgenHook];});
        cargoArtifacts-windows = craneLib-windows.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs_windows.rustPlatform.bindgenHook];});

        my-crate = craneLib.buildPackage (
          commonArgs // {inherit cargoArtifacts;}
        );
        my-crate-aarch64 = craneLib-aarch64.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts-aarch64;
            CARGO_BUILD_TARGET = "aarch64-unknown-linux-musl";
          }
        );
        my-crate-arm = craneLib-arm.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts-arm;
            CARGO_BUILD_TARGET = "armv7-unknown-linux-musleabihf";
          }
        );
        my-crate-amd64 = craneLib-amd64.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts-amd64;
            CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          }
        );
        my-crate-windows = craneLib-windows.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts-windows;
            CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
          }
        );
      in {
        packages = {
          default = my-crate;
          cross-aarch64 = my-crate-aarch64;
          cross-arm = my-crate-arm;
          cross-amd64 = my-crate-amd64;
          cross-windows = my-crate-windows;
        };
        devShells = {
          default = craneLib.devShell {packages = nativeBuildInputs ++ [pkgs.rustPlatform.bindgenHook];};
          cross-aarch64 = craneLib-aarch64.devShell {packages = nativeBuildInputs ++ [pkgs_aarch64.rustPlatform.bindgenHook];};
          cross-arm = craneLib-arm.devShell {packages = nativeBuildInputs ++ [pkgs_arm.rustPlatform.bindgenHook];};
          cross-amd64 = craneLib-amd64.devShell {packages = nativeBuildInputs ++ [pkgs_amd64.rustPlatform.bindgenHook];};
          cross-windows = craneLib-windows.devShell {packages = nativeBuildInputs ++ [pkgs_windows.rustPlatform.bindgenHook];};
        };
      }
    );
}
