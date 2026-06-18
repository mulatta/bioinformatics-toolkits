{ pkgs }:
{
  folddisco = pkgs.callPackage ./folddisco { };
  foldseek = pkgs.callPackage ./foldseek { };
  nupack = pkgs.callPackage ./nupack { };
}
// pkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
  interproscan = pkgs.callPackage ./interproscan { };
}
