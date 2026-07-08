{
  description = "bioinformatics-toolkits — Nix package registry for bioinformatics";

  inputs = {
    # keep-sorted start
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    # keep-sorted end
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      eachSystem =
        f:
        lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
        );

      treefmtEval = eachSystem (
        { pkgs, ... }:
        treefmt-nix.lib.evalModule pkgs {
          projectRootFile = "flake.nix";
          programs = {
            deadnix.enable = true;
            keep-sorted.enable = true;
            nixfmt.enable = true;
            # Markdown only; the sole JSON file (flake.lock) is Nix-managed.
            prettier = {
              enable = true;
              includes = [
                "*.md"
                "*.markdown"
              ];
            };
            ruff-format.enable = true;
            statix.enable = true;
          };
        }
      );
      packages = eachSystem ({ pkgs, ... }: import ./packages { inherit pkgs; });

      devShells = eachSystem (
        { pkgs, ... }:
        {
          default = import ./shell.nix { inherit pkgs; };
        }
      );
    in
    {
      inherit packages devShells;

      herculesCI = import ./ci/effects.nix { inherit nixpkgs; };

      overlays.default = import ./overlays.nix;

      checks = eachSystem (
        { system, ... }:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (
          lib.filterAttrs (
            _: p:
            # Skip packages not buildable on this system: requireFile ones are
            # registration-gated (marked passthru.requireFile = true), and others
            # are simply unsupported on the host (meta.platforms) — checking
            # either just produces a guaranteed failure.
            (lib.meta.availableOn { inherit system; } p) && !(p.requireFile or false)
          ) packages.${system}
        )
        // lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") devShells.${system}
      );

      formatter = eachSystem ({ system, ... }: treefmtEval.${system}.config.build.wrapper);
    };
}
