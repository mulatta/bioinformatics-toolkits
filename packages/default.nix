# Flat package set. Each package lives in packages/<name>/default.nix.
{ pkgs }:
{
  foldseek = pkgs.callPackage ./foldseek { };
}
