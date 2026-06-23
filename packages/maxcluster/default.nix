{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# MaxCluster — protein structure comparison and clustering (Alex Herbert,
# Imperial College). Used by EVcouplings' fold stage to compare/cluster the
# predicted 3D models. Upstream ships only a pre-compiled, statically linked
# binary with no source and no explicit licence, so it is marked unfree.
stdenvNoCC.mkDerivation {
  pname = "maxcluster";
  version = "0.6.6";

  src = fetchurl {
    url = "https://www.sbg.bio.ic.ac.uk/~maxcluster/maxcluster64bit";
    hash = "sha256-ym3uj68GSUedGMTXWM/dAccXUOMJNya1FkaUhgUJCqY=";
  };

  dontUnpack = true;

  # Statically linked (no interpreter / NEEDED libs), so no autoPatchelf needed.
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/maxcluster
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/maxcluster --version 2>&1 | grep -q "maxcluster 0.6.6" \
      || { echo "maxcluster did not report expected version"; exit 1; }
    echo "install check OK"
    runHook postInstallCheck
  '';

  passthru.category = "Protein Structure Search & Alignment";

  meta = {
    description = "Protein structure comparison and clustering";
    homepage = "https://www.sbg.bio.ic.ac.uk/~maxcluster/";
    license = lib.licenses.unfree;
    # Upstream provides only a 64-bit x86 Linux binary.
    platforms = [ "x86_64-linux" ];
    mainProgram = "maxcluster";
  };
}
