# Local CLI entrypoint for package documentation metadata.
# CI imports package-docs-metadata.nix during flake evaluation instead of
# running nested Nix inside a sandboxed build.
# Uses x86_64-linux purely for meta evaluation; no build is performed, so the
# host platform is irrelevant.
let
  flake = builtins.getFlake (toString ./..);
in
import ./package-docs-metadata.nix {
  packages = flake.packages.x86_64-linux;
}
