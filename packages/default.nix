{ pkgs }:
# rec: consurf bundles our own rate4site (not in nixpkgs) on its PATH.
rec {
  biotite = pkgs.callPackage ./biotite { };
  consurf = pkgs.callPackage ./consurf { inherit rate4site; };
  folddisco = pkgs.callPackage ./folddisco { };
  foldmason = pkgs.callPackage ./foldmason { };
  foldseek = pkgs.callPackage ./foldseek { };
  gemme = pkgs.callPackage ./gemme { };
  nupack = pkgs.callPackage ./nupack { };
  rate4site = pkgs.callPackage ./rate4site { };
  thermompnn = pkgs.callPackage ./thermompnn { };
  usalign = pkgs.callPackage ./usalign { };
}
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  interproscan = pkgs.callPackage ./interproscan { };
}
