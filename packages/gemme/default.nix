{
  lib,
  stdenv,
  fetchurl,
  callPackage,
  jdk8,
  jre8,
  python3,
  rWrapper,
  rPackages,
  makeWrapper,
  blast,
  hh-suite,
  # naccess is non-free and not publicly distributable (registration-gated via
  # Simon Hubbard); upstream's own Docker image does not bundle it either. Leave
  # it unset by default — the structure/interface mode's code path is wired, and
  # users who hold a naccess licence can supply it with
  # `gemme.override { naccess = <their-naccess-pkg>; }` to enable that mode.
  naccess ? null,
}:
# GEMME (Global Epistatic Model for predicting Mutational Effects) is a thin
# Python orchestrator around two engines: JET2 (Java, computes the evolutionary
# trace) and an R model (global epistasis). Upstream ships it only as a Docker
# image, but the sources are MIT-licensed tarballs and the whole pipeline builds
# natively. All modes are wired:
#   * variant effect from a precomputed MSA (-r input)        -> JET2 + R
#   * homolog retrieval / MSA building (-r local | -r server) -> blast + muscle + hh-suite
#   * structure / interface analysis                          -> naccess (user-supplied, see above)
let
  rEnv = rWrapper.override {
    packages = with rPackages; [
      seqinr
      RColorBrewer
    ];
  };

  # JET2 aligns retrieved homologs with `muscle -in .. -clw -out ..`; only the
  # legacy MUSCLE 3.8 understands those flags (nixpkgs ships MUSCLE 5).
  muscle = callPackage ./muscle3.nix { };

  # Tools JET2 shells out to, read from default.conf by absolute path.
  naccessBin = if naccess != null then "${naccess}/bin/naccess" else "naccess";
in
stdenv.mkDerivation {
  pname = "gemme";
  version = "1.0-unstable-2024-08";

  srcs = [
    (fetchurl {
      url = "http://www.lcqb.upmc.fr/GEMME/package/GEMME.tgz";
      hash = "sha256-R3k41qNgTtM5T5TsKZAENFHbTqP5T2l1kCD3puijlmE=";
    })
    (fetchurl {
      url = "http://www.lcqb.upmc.fr/JET2/package/JET2.tgz";
      hash = "sha256-K0q7RZvSoIiTeUsplQon9EuHfA6pca+eV/iu7Y8Ulz8=";
    })
  ];

  # Two tarballs unpack to GEMME/ and JET2/ side by side.
  sourceRoot = ".";

  nativeBuildInputs = [
    jdk8
    makeWrapper
  ];

  postPatch = ''
    # Strip macOS AppleDouble / editor junk shipped in the tarballs.
    find . \( -name '._*' -o -name '*~' -o -name '*.pyc' -o -name '.*.swp' \) -delete

    # Make GEMME run on Python 3 (avoids the EOL/insecure python2). Two fixes:
    #  1. six `print` statements -> print() calls;
    #  2. leading tab/space mix that Python 3 rejects -> normalise leading tabs
    #     to spaces (expand -i only touches indentation, not string literals).
    for f in GEMME/gemme.py GEMME/gemmeAnal.py; do
      sed -i -E 's/^([[:space:]]*)print (.+)$/\1print(\2)/' "$f"
      expand -i -t 8 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    done

    # JET2's full-matrix path copies default.conf into the run dir and then
    # rewrites it (editConfJET's `sed -i`, and JET's own FileWriter). `cp`
    # carries over the source mode, and our conf lives read-only in the Nix
    # store (0444), so the copy is read-only too and those writes fail with
    # Permission denied. Make the working copy writable right after it lands.
    substituteInPlace GEMME/gemmeAnal.py \
      --replace-fail 'cp $GEMME_PATH/default.conf .' \
                     'cp $GEMME_PATH/default.conf . && chmod u+w default.conf'

    # cleanTheMess() unconditionally `os.remove(prot+".pdb")`, but the
    # full-matrix path never writes that dummy PDB, so cleanup dies with
    # FileNotFoundError. Every other removal in the function is already guarded
    # with os.path.isfile; guard this one the same way.
    substituteInPlace GEMME/gemmeAnal.py \
      --replace-fail 'os.remove(prot+".pdb")' \
                     'os.path.isfile(prot+".pdb") and os.remove(prot+".pdb")'
  '';

  buildPhase = ''
    runHook preBuild
    # Compile the JET2 Java engine (bundled Java3D jars on the classpath).
    pushd JET2
    # Sources carry Latin-1 French comments; pin the encoding so javac does not
    # fall back to the sandbox's ASCII locale and choke on accented bytes.
    javac -encoding ISO-8859-1 \
      -cp ".:jet/extLibs/vecmath.jar:jet/extLibs/j3dcore.jar:jet/extLibs/j3dutils.jar" \
      jet/JET.java
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/gemme $out/share/jet2 $out/bin
    cp -r GEMME/. $out/share/gemme/
    cp -r JET2/. $out/share/jet2/

    # Repoint every hard-coded tool/data path in default.conf at the Nix store.
    # The bundled substitution matrices live in JET2/matrix; the external tools
    # come from their respective packages (naccess is user-supplied, see above).
    substituteInPlace $out/share/gemme/default.conf \
      --replace-fail /opt/JET2/matrix $out/share/jet2/matrix \
      --replace-fail /usr/bin/muscle ${muscle}/bin/muscle \
      --replace-fail /opt/blast-2.2.27+/bin/psiblast ${blast}/bin/psiblast \
      --replace-fail /opt/JET2/naccess2.1.1/naccess ${naccessBin}

    # gemme.py reads $GEMME_PATH and $JET_PATH and shells out to java/Rscript;
    # JET2 in turn calls blast/muscle/hhblits (and naccess when configured).
    makeWrapper ${python3}/bin/python3 $out/bin/gemme \
      --add-flags $out/share/gemme/gemme.py \
      --set GEMME_PATH $out/share/gemme \
      --set JET_PATH $out/share/jet2 \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            jre8
            rEnv
            blast
            muscle
            hh-suite
          ]
          ++ lib.optional (naccess != null) naccess
        )
      }
    runHook postInstall
  '';

  passthru = {
    category = "Evolution & Variation";
    # Upstream distributes an undated tarball with no version tags; nothing for
    # the auto-updater to track.
    skipUpdate = true;
  };

  meta = {
    description = "Predict mutational effects from evolutionary conservation and global epistasis";
    homepage = "http://www.lcqb.upmc.fr/GEMME/";
    license = lib.licenses.mit;
    # Bundled muscle3 (./muscle3.nix) ships an x86_64-linux-only binary.
    platforms = [ "x86_64-linux" ];
    mainProgram = "gemme";
  };
}
