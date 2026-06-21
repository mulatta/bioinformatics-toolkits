{ pkgs }:
{
  folddisco = pkgs.callPackage ./folddisco { };
  foldmason = pkgs.callPackage ./foldmason { };
  foldseek = pkgs.callPackage ./foldseek { };
  nupack = pkgs.callPackage ./nupack { };
  rate4site = pkgs.callPackage ./rate4site { };
  usalign = pkgs.callPackage ./usalign { };
}
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  interproscan = pkgs.callPackage ./interproscan { };
}
