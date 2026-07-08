{
  self,
  lib,
  eachSystem,
  packages,
  devShells,
  treefmtEval,
}:

eachSystem (
  { system, pkgs, ... }:
  let
    packageDocsMetadata = pkgs.writeText "package-docs-metadata.json" (
      builtins.toJSON (import ../scripts/package-docs-metadata.nix { packages = packages.${system}; })
    );

    generatedPackageDocs = pkgs.runCommand "generated-package-docs-check" { } ''
      cp -R ${self} source
      chmod -R u+w source
      cd source

      ${pkgs.python3}/bin/python3 scripts/generate-package-docs.py \
        --check \
        --metadata-json ${packageDocsMetadata}
      touch $out
    '';
  in
  {
    formatting = treefmtEval.${system}.config.build.check self;
    generated-package-docs = generatedPackageDocs;
  }
  // lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (
    lib.filterAttrs (
      _: p:
      # Skip packages not buildable on this system: requireFile ones are
      # registration-gated (marked passthru.requireFile = true), and others
      # are simply unsupported on the host (meta.platforms) — checking either
      # just produces a guaranteed failure.
      (lib.meta.availableOn { inherit system; } p) && !(p.requireFile or false)
    ) packages.${system}
  )
  // lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") devShells.${system}
)
