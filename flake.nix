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
        overlays = [fenix.overlays.default];
        pkgs = import nixpkgs {inherit system overlays;};
        pkgs_aarch64 = import nixpkgs {
          inherit overlays;
          localSystem = system;
          crossSystem = pkgs.lib.systems.examples.aarch64-multiplatform-musl;
        };
        pkgs_arm = import nixpkgs {
          inherit overlays;
          localSystem = system;
          crossSystem.config = "armv7l-unknown-linux-musleabihf";
        };
        pkgs_amd64 = import nixpkgs {
          inherit overlays;
          localSystem = system;
          crossSystem = pkgs.lib.systems.examples.musl64;
        };
        # https://github.com/NixOS/nixpkgs/tree/master/pkgs/os-specific/windows/msvcSdk
        # add windows.sdk to native build inputs
        # pkgs_windows = import nixpkgs {
        #   inherit overlays;
        #   localSystem = system;
        #   crossSystem.config = "x86_64-pc-windows-msvc";
        #   config.microsoftVisualStudioLicenseAccepted = true;
        #   config.allowUnfree = true;
        # };

        rustToolchain = fenix.packages.${system}.fromToolchainFile {
          file = ./rust-toolchain.toml;
          sha256 = "sha256-+9FmLhAOezBZCOziO0Qct1NOrfpjNsXxc/8I0c7BdKE=";
        };

        exampleDependency = builtins.fetchurl {
          url = "https://github.com/jibsen/parg/archive/refs/tags/v1.0.3.zip";
          sha256 = "sha256:072irh6fc4w2xc0nmj668i3v24w7pz4s5sk7g5zbcdrb659hfsz7";
        };

        src = ./.;

        nativeBuildInputs = [
          rustToolchain
          # rustPlatform.bindgenHook
          pkgs.rust-bindgen
          pkgs.just
          pkgs.nushell
          pkgs.p7zip
          # pkgs_windows.windows.sdk
        ];

        commonEnvVars = {
          # https://github.com/rust-lang/rust-bindgen?tab=readme-ov-file#environment-variables
          BINDGEN_EXTRA_CLANG_ARGS_aarch64_unknown_linux_musl = builtins.concatStringsSep " " [
            "--target=aarch64-unknown-linux-musl"
            "-I${pkgs_aarch64.libclang.lib}/lib/clang/${pkgs.lib.versions.major (pkgs.lib.getVersion pkgs_aarch64.clang)}/include"
          ];
          BINDGEN_EXTRA_CLANG_ARGS_armv7_unknown_linux_musleabihf = builtins.concatStringsSep " " [
            "--target=armv7-unknown-linux-musleabihf"
            "-I${pkgs_arm.libclang.lib}/lib/clang/${pkgs.lib.versions.major (pkgs.lib.getVersion pkgs_arm.clang)}/include"
          ];
          BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_musl = builtins.concatStringsSep " " [
            "--target=x86_64-unknown-linux-musl"
            "-I${pkgs_amd64.libclang.lib}/lib/clang/${pkgs.lib.versions.major (pkgs.lib.getVersion pkgs_amd64.clang)}/include"
          ];
          # BINDGEN_EXTRA_CLANG_ARGS_x86_64_pc_windows_msvc = builtins.concatStringsSep " " [
          #   "--target=x86_64-pc-windows-msvc"
          #   "-I${pkgs_windows.libclang.lib}/lib/clang/${pkgs.lib.versions.major (pkgs.lib.getVersion pkgs_windows.clang)}/include"
          # ];
          CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_DEBUG = true;
          CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgs_aarch64.stdenv.cc}/bin/${pkgs_aarch64.stdenv.cc.targetPrefix}gcc";
          CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABIHF_LINKER = "${pkgs_arm.stdenv.cc}/bin/${pkgs_arm.stdenv.cc.targetPrefix}gcc";
          CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER = "${pkgs_amd64.stdenv.cc}/bin/${pkgs_amd64.stdenv.cc.targetPrefix}gcc";
          # CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_LINKER = "${pkgs_windows.stdenv.cc}/bin/${pkgs_windows.stdenv.cc.targetPrefix}gcc";
          CC_ENABLE_DEBUG_OUTPUT = true;
          CC_aarch64_unknown_linux_musl = "${pkgs_aarch64.stdenv.cc}/bin/${pkgs_aarch64.stdenv.cc.targetPrefix}gcc";
          CC_armv7_unknown_linux_musl = "${pkgs_arm.stdenv.cc}/bin/${pkgs_arm.stdenv.cc.targetPrefix}gcc";
          CC_x86_64_unknown_linux_musl = "${pkgs_amd64.stdenv.cc}/bin/${pkgs_amd64.stdenv.cc.targetPrefix}gcc";
          # CC_x86_64_pc_windows_msvc = "${pkgs_windows.stdenv.cc}/bin/${pkgs_windows.stdenv.cc.targetPrefix}gcc";
          CRATE_CC_NO_DEFAULTS = true;
          # Bindgen seems to want this to point to host's libclang, even when cross-compiling
          LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
          RUST_BACKTRACE = 1;
          # NIXPKGS_ALLOW_UNFREE = 1;
        };

        commonArgs =
          {
            inherit src nativeBuildInputs;
            strictDeps = true;

            preBuild = ''
              if [ -z "''${CRANE_BUILD_DEPS_ONLY:-}"]; then
                echo "Setting up downloads folder"
                mkdir -p _downloads
                cp ${exampleDependency} _downloads/parg-1.0.3.zip
                ${pkgs.just}/bin/just download_deps
                echo "Done setting up downloads folder"
              fi
            '';
          }
          // commonEnvVars;

        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;
        craneLib-aarch64 = (crane.mkLib pkgs_aarch64).overrideToolchain rustToolchain;
        craneLib-arm = (crane.mkLib pkgs_arm).overrideToolchain rustToolchain;
        craneLib-amd64 = (crane.mkLib pkgs_amd64).overrideToolchain rustToolchain;
        # craneLib-windows = (crane.mkLib pkgs_windows).overrideToolchain rustToolchain;

        cargoArtifacts = craneLib.buildDepsOnly (commonArgs // {nativeBuildInputs = [pkgs.rustPlatform.bindgenHook];});
        cargoArtifacts-aarch64 = craneLib-aarch64.buildDepsOnly (commonArgs // {CARGO_BUILD_TARGET = "aarch64-unknown-linux-musl";});
        cargoArtifacts-arm = craneLib-arm.buildDepsOnly (commonArgs // {CARGO_BUILD_TARGET = "armv7-unknown-linux-musleabihf";});
        cargoArtifacts-amd64 = craneLib-amd64.buildDepsOnly (commonArgs // {CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";});
        # cargoArtifacts-windows = craneLib-windows.buildDepsOnly (commonArgs // {CARGO_BUILD_TARGET = "x86_64-pc-windows-msvc";});

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
        # my-crate-windows = craneLib-windows.buildPackage (
        #   commonArgs
        #   // {
        #     inherit cargoArtifacts-windows;
        #     CARGO_BUILD_TARGET = "x86_64-pc-windows-msvc";
        #   }
        # );
      in {
        packages = {
          default = my-crate;
          cross-aarch64 = my-crate-aarch64;
          cross-arm = my-crate-arm;
          cross-amd64 = my-crate-amd64;
          # cross-windows = my-crate-windows;
        };
        devShells = {
          default = craneLib.devShell {packages = nativeBuildInputs ++ [pkgs.rustPlatform.bindgenHook];};
          cross = craneLib.devShell ({
              packages = nativeBuildInputs;
            }
            // commonEnvVars);
        };
      }
    );
}
