# Flat package set. Each package lives in packages/<name>/default.nix.
{ pkgs }:
{
  folddisco = pkgs.callPackage ./folddisco { };
  foldmason = pkgs.callPackage ./foldmason { };
  foldseek = pkgs.callPackage ./foldseek { };
  nupack = pkgs.callPackage ./nupack { };
  usalign = pkgs.callPackage ./usalign { };
}
