{ pkgs }:
pkgs.mkShell {
  packages = with pkgs; [
    nix-update
    gh
  ];
}
