# Flat package set. Each package lives in packages/<name>/default.nix.
{ pkgs }:
{
  folddisco = pkgs.callPackage ./folddisco { };
  foldseek = pkgs.callPackage ./foldseek { };
  nupack = pkgs.callPackage ./nupack { };
}
