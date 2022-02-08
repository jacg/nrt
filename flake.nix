# This file is pretty general, and you can adapt it in your project replacing
# only `name` and `description` below.

{
  description = "My awesome Rust project";

  inputs = {
    nixpkgs         .url = "github:nixos/nixpkgs/nixos-unstable";
    utils           .url = "github:numtide/flake-utils";
    rust-overlay    .url = "github:oxalica/rust-overlay";
    crate2nix    = { url = "github:kolloch/crate2nix";     flake = false; };
    flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
  };

  outputs = { self, nixpkgs, utils, rust-overlay, crate2nix, ... }:
    let
      # This name must match the name in Cargo.toml
      name = "nixified-rust-project";
      rustChannel = "stable";
    in
    utils.lib.eachDefaultSystem
      (system:
        let
          # Imports
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlay
              (final: prev:
                let
                  extras = {
                    extensions = [
                      "rust-analyzer-preview"
                      "rust-analysis"
                      # "does-not-exist" # Uncomment this line to generate an error message show list of available extensions
                    ];
                    #targets = [ "arg-unknown-linux-gnueabihf" ];
                  };
                  # If you have a rust-toolchain file for rustup, choose `rustup =
                  # rust-tcfile` further down to get the customized toolchain
                  # derivation.
                  rust-tcfile  = final.rust-bin.fromRustupToolchainFile ./rust-toolchain;
                  rust-latest  = final.rust-bin.stable .latest      ;
                  rust-beta    = final.rust-bin.beta   .latest      ;
                  rust-nightly = final.rust-bin.nightly."2022-02-07";
                  rust-stable  = final.rust-bin.stable ."1.58.1"    ; # nix flake lock --update-input rust-overlay
                  rust-analyzer-preview-on = date:
                    final.rust-bin.nightly.${ date }.default.override
                      { extensions = [ "rust-analyzer-preview" ]; };
                in

                  rec {

                    # The version of the Rust system to be used in buldiInputs. Choose between
                    # tcfile/latest/beta/nightly/stable on the next line
                    rustup = rust-stable;

                    # Because rust-overlay bundles multiple rust packages into one
                    # derivation, specify that mega-bundle here, so that crate2nix
                    # will use them automatically.
                    rustc = rustup.default;
                    cargo = rustup.default;
                    rust-analyzer-preview = rust-analyzer-preview-on "2022-02-07";
                  })
            ];
          };
          inherit (import "${crate2nix}/tools.nix" { inherit pkgs; })
            generatedCargoNix;

          # Create the cargo2nix project
          project = pkgs.callPackage
            (generatedCargoNix {
              inherit name;
              src = ./.;
            })
            {
              # Individual crate overrides go here
              # Example: https://github.com/balsoft/simple-osd-daemons/blob/6f85144934c0c1382c7a4d3a2bbb80106776e270/flake.nix#L28-L50
              defaultCrateOverrides = pkgs.defaultCrateOverrides // {
                # The himalaya crate itself is overriden here. Typically we
                # configure non-Rust dependencies (see below) here.
                ${name} = oldAttrs: {
                  inherit buildInputs nativeBuildInputs;
                };
              };
            };

          # Configuration for the non-Rust dependencies
          buildInputs = [ pkgs.openssl.dev ];
          nativeBuildInputs = [ pkgs.rustc pkgs.cargo pkgs.pkgconfig ];
        in
        rec {
          packages.${name} = project.rootCrate.build;

          # `nix build`
          defaultPackage = packages.${name};

          # `nix run`
          apps.${name} = utils.lib.mkApp {
            inherit name;
            drv = packages.${name};
          };
          defaultApp = apps.${name};

          # `nix develop`
          devShell = pkgs.mkShell
            {
              inputsFrom = builtins.attrValues self.packages.${system};
              buildInputs = buildInputs ++ ([
                # Tools you need for development go here.
                pkgs.rust-analyzer-preview
                pkgs.nixpkgs-fmt
                pkgs.cargo-watch
                pkgs.rustup.rust-analysis
                pkgs.rustup.rls
                ]);
              RUST_SRC_PATH = "${pkgs.rustup.rust-src}/lib/rustlib/src/rust/library";
            };
        }
      );
}
