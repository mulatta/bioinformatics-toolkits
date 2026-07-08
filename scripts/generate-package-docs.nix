# Extract documentation metadata for every package in the flake.
# Evaluated via `nix eval --json` by generate-package-docs.py.
# Uses x86_64-linux purely for meta evaluation; no build is performed, so the
# host platform is irrelevant.
let
  flake = builtins.getFlake (toString ./..);
in
import ./package-docs-metadata.nix {
  packages = flake.packages.x86_64-linux;
}
