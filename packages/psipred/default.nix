{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  tcsh,
  coreutils,
  # runpsipred (the PSI-BLAST path) needs a legacy NCBI blastpgp/makemat, which
  # nixpkgs' blast+ does not provide, plus a formatted sequence DB. Left null: the
  # self-contained runpsipred_single path needs none of this. A user with legacy
  # BLAST can supply it via `psipred.override { blast = <pkg>; }`.
  blast ? null,
}:
# PSIPRED V4 — protein secondary structure prediction (Jones lab, UCL). Used by
# EVcouplings' fold stage to generate secondary-structure restraints. Builds four
# small C programs; the runpsipred* tcsh driver scripts are wrapped so they locate
# the binaries/data in the store and find tcsh + hostid at runtime.
stdenv.mkDerivation (_finalAttrs: {
  pname = "psipred";
  # Repo has no release tags; track master HEAD by commit date (README: V4).
  version = "4.0";

  src = fetchFromGitHub {
    owner = "psipred";
    repo = "psipred";
    rev = "4e8d136076bc0af1534cac053cb54d1ee641571a";
    hash = "sha256-nQDTqmf0OgcoYceDhR/EKqnaQeUaZ22EszzOPOUfTyM=";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildPhase = ''
    runHook preBuild
    # The repo commits prebuilt (FHS-linked) binaries next to the sources; make
    # would keep them and we'd ship binaries with a /lib64 interpreter that fail
    # in the sandbox. Remove them so everything recompiles against the Nix
    # toolchain (the Makefile's own `clean` calls /bin/rm, absent in the sandbox).
    rm -f src/psipred src/psipass2 src/chkparse src/seq2mtx
    # The sources are pre-ANSI K&R C (implicit int, old malloc/calloc decls) that
    # GCC 14+ rejects by default; -std=gnu89 keeps these as warnings.
    make -C src all CC=$CC CFLAGS="-O -std=gnu89"
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/libexec/psipred $out/share/psipred/data

    install -Dm755 src/psipred src/psipass2 src/chkparse src/seq2mtx -t $out/bin
    cp -r data/. $out/share/psipred/data/

    # The driver scripts hardcode relative ./bin and ./data and a /bin/tcsh
    # shebang. Repoint them at the store so they work from any directory, then
    # wrap each so tcsh and hostid (used for temp-file naming) are on PATH.
    for s in runpsipred runpsipred_single; do
      cp $s $out/libexec/psipred/$s
      substituteInPlace $out/libexec/psipred/$s \
        --replace-fail '#!/bin/tcsh' '#!${tcsh}/bin/tcsh' \
        --replace-fail 'set execdir = ./bin' "set execdir = $out/bin" \
        --replace-fail 'set datadir = ./data' "set datadir = $out/share/psipred/data"
      makeWrapper $out/libexec/psipred/$s $out/bin/$s \
        --prefix PATH : ${lib.makeBinPath ([ coreutils ] ++ lib.optional (blast != null) blast)}
    done
    runHook postInstall
  '';

  # Real-data smoke test: the DB-free single-sequence path on the bundled example
  # FASTA must produce a .ss2 secondary-structure prediction.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cp example/example.fasta query.fasta
    $out/bin/runpsipred_single query.fasta
    test -s query.ss2 || { echo "psipred produced no .ss2 prediction"; exit 1; }
    echo "install check OK: $(wc -l < query.ss2) lines in query.ss2"
    runHook postInstallCheck
  '';

  passthru.category = "Sequence & Structure Analysis";

  meta = {
    description = "PSIPRED V4 protein secondary structure prediction";
    homepage = "https://github.com/psipred/psipred";
    # Free for academic and commercial research; may not be resold or bundled
    # into a commercial product/service (custom UCL licence).
    license = lib.licenses.unfree;
    platforms = lib.platforms.unix;
  };
})
