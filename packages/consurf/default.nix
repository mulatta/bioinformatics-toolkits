{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  python3,
  dejavu_fonts,
  hmmer,
  cd-hit,
  mafft,
  muscle,
  blast,
  mmseqs2,
  rate4site,
}:
let
  pyEnv = python3.withPackages (ps: [
    ps.biopython
    ps.fpdf
  ]);

  # Tools the pipeline shells out to by bare name: MAFFT/MUSCLE (alignment),
  # HMMER/BLAST/MMseqs2 (homolog search), CD-HIT (redundancy filter), and our
  # rate4site (conservation rates). CLUSTALW/PRANK (alternative aligners) and
  # prottest/jModelTest (the "BEST" model search, which degrades to JTT when
  # absent) are not in nixpkgs and are omitted; pass an explicit --model and use
  # --align MAFFT or MUSCLE.
  runtimeTools = [
    hmmer
    cd-hit
    mafft
    muscle
    blast
    mmseqs2
    rate4site
  ];
in
stdenv.mkDerivation {
  pname = "consurf";
  # Standalone ConSurf is "v1.00" (Yariv et al. 2023) but the repo carries no
  # tags; update.py tracks its default-branch HEAD by commit date.
  version = "1.00-unstable-2026-06-15";

  src = fetchFromGitHub {
    owner = "Barak19";
    repo = "stand_alone_consurf";
    rev = "8b7ef3fcf0965645672abdabb694edead60f9fe9";
    hash = "sha256-R1U1BpTUZC9P6mJtGzTUDijdl/wJ8xMwlYUIwVtP1Iw=";
  };

  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;

  postPatch = ''
    # rate4site: the active code path (run_rate4site_old) shells out to bundled
    # prebuilt binaries under rate4site_bioseq/. We package that exact lineage
    # (Debian 3.0.0, byte-identical output) as rate4site, so point all three
    # calls at it on PATH. Our rate4site is already the -DDOUBLEREP build the web
    # server uses; -ib selects Bayesian and -im Maximum-Likelihood, so one binary
    # covers the regular, ML, and underflow-fallback invocations.
    substituteInPlace stand_alone_consurf.py \
      --replace-fail "vars['script_dir'] + \"/rate4site_bioseq/rate4site.24Mar2010\"" '"rate4site"' \
      --replace-fail "vars['script_dir'] + \"/rate4site_bioseq/rate4site.doubleRep\"" '"rate4site"' \
      --replace-fail "vars['script_dir'] + \"/rate4site_bioseq/rate4site\"" '"rate4site"'

    # PDF report font (server-hardcoded absolute path).
    substituteInPlace GENERAL_CONSTANTS.py \
      --replace-fail "/bentallab/programs/dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf" \
                     "${dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf"
  '';

  # The script reads its data files (WEIGHT.BIN, matrices, colour-session
  # templates) relative to its own location, so keep them together and point a
  # wrapper at it with the interpreter and tools on PATH.
  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/consurf \
      stand_alone_consurf.py GENERAL_CONSTANTS.py matrix.txt matrix-nuc.txt \
      WEIGHT.BIN \
      color_consurf_chimerax_session.py color_consurf_CBS_chimerax_session.py \
      color_consurf_pymol_isd_session.py color_consurf_CBS_pymol_isd_session.py
    makeWrapper ${pyEnv}/bin/python3 $out/bin/consurf \
      --add-flags "$out/share/consurf/stand_alone_consurf.py" \
      --prefix PATH : ${lib.makeBinPath runtimeTools}
    runHook postInstall
  '';

  passthru.category = "Phylogenetics & Evolutionary Analysis";

  meta = {
    description = "Standalone ConSurf: evolutionary conservation of amino-acid/nucleotide positions, web-server equivalent";
    homepage = "https://consurf.tau.ac.il";
    # Upstream ships no license file; ConSurf is distributed for academic use.
    license = {
      fullName = "ConSurf academic use (no upstream license file)";
      free = false;
    };
    platforms = lib.platforms.unix;
    mainProgram = "consurf";
  };
}
