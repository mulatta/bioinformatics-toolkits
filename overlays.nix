# Additive overlay exposing every package in ./packages on a nixpkgs instance,
# e.g. `import nixpkgs { overlays = [ bio.overlays.default ]; }`. Reuses
# ./packages as the single source of truth; names are collision-free with
# nixpkgs, so it only adds attrs (never overrides).
#
# Uses `prev`, not `final`: ./packages selects its attribute *set* by host
# platform (optionalAttrs ... x86_64-linux), and keying that on `final` makes the
# overlay's attr names depend on `final.stdenv` -> infinite recursion. Packages
# are additive, so `prev` is equivalent here.
_final: prev: import ./packages { pkgs = prev; }
