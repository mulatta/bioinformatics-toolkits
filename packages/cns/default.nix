{
  lib,
  stdenv,
  requireFile,
  tcsh,
  gfortran,
  flex,
  perl,
  makeWrapper,
}:
# CNS (Crystallography & NMR System) — the structure-determination engine behind
# EVcouplings' optional fold (3D) stage. Distributed only after registration at
# http://cns-online.org/cns_request/ (download sits behind a Cloudflare challenge,
# so it cannot be fetched headlessly) under a non-commercial licence — hence
# requireFile + unfree.
let
  # CNS only recognises x86_64 Linux among Linux targets (bin/getarch has no
  # aarch64-linux case).
  cnsArch = "intel-x86_64bit-linux";
in
stdenv.mkDerivation (_finalAttrs: {
  pname = "cns";
  version = "1.3_r9";

  # Download cns_v1.3_r9.tar.gz in a browser (the cns-online.org download is
  # behind Cloudflare), copy it here, then add it to the store:
  #   nix-store --add-fixed sha256 cns_v1.3_r9.tar.gz
  src = requireFile {
    name = "cns_v1.3_r9.tar.gz";
    hash = "sha256-bb5wWc9YXCXwXDTtTZRT7rZ3YY/cxFIGB/ObqTkYQ90=";
    url = "https://cns-online.org/download/v1.3/cns_v1.3_r9.tar.gz";
    message = ''
      CNS sits behind a Cloudflare challenge and cannot be downloaded headlessly.
      Download cns_v1.3_r9.tar.gz in a browser, copy it to this machine, then run:
        nix-store --add-fixed sha256 cns_v1.3_r9.tar.gz
    '';
  };

  sourceRoot = "cns_v1.3_r9";

  nativeBuildInputs = [
    tcsh
    gfortran
    flex
    perl
    makeWrapper
  ];

  postPatch = ''
    # The tarball is packed on macOS; drop AppleDouble / .DS_Store junk.
    find . \( -name '._*' -o -name '.DS_Store' \) -delete

    # CNS predates PATH-based tool lookup: its Makefiles, scripts and /bin/csh
    # shebangs call absolute /bin/<tool> paths absent from the sandbox. Repoint
    # them (/bin/sh does exist, so leave it). /bin/rm also rewrites /bin/rmdir.
    # /usr/bin/perl is handled before /bin/perl to avoid clobbering it.
    grep -rlIZ -e /bin/csh -e /bin/rm -e /bin/ls -e /bin/ln -e /bin/echo -e /bin/perl . \
      | xargs -0 -r sed -i \
        -e 's@/bin/csh@${tcsh}/bin/tcsh@g' \
        -e 's@/bin/rm@rm@g' \
        -e 's@/bin/ls@ls@g' \
        -e 's@/bin/ln@ln@g' \
        -e 's@/bin/echo@echo@g' \
        -e 's@/usr/bin/perl@perl@g' \
        -e 's@/bin/perl@perl@g'

    # The gfortran header already carries -fallow-argument-mismatch (needed for
    # gfortran 10+), but its -fopenmp makes the FFT3C startup self-test fail.
    # Adopt the HADDOCK-recommended flags (proven to pass the self-test): drop
    # -fopenmp everywhere and add -funroll-loops -ffast-math, while dropping
    # -march=native so the build stays reproducible.
    substituteInPlace instlib/machine/supported/${cnsArch}/Makefile.header.1.gfortran \
      --replace-fail "F77 = gfortran -fopenmp" "F77 = gfortran" \
      --replace-fail "-O3 -march=native -fopenmp" "-O3 -funroll-loops -ffast-math" \
      --replace-fail "LDFLAGS = -fopenmp " "LDFLAGS = "
  '';

  buildPhase = ''
    runHook preBuild
    builddir=$PWD

    # Both env scripts hardcode the author's absolute path; point them at the
    # build tree so `make install` (which sources the csh env) resolves CNS_SOLVE.
    for env in cns_solve_env cns_solve_env_sh; do
      substituteInPlace $env \
        --replace-fail /Users/brunger/Dropbox/cns_v1.3_r9 "$builddir"
    done

    source ./cns_solve_env_sh
    # Makefile hardcodes CSHELL=/bin/csh (absent in the sandbox); use tcsh.
    make install compiler=gfortran CSHELL=${tcsh}/bin/tcsh
    runHook postBuild
  '';

  # The cns_solve executable is linked correctly by the Nix toolchain already;
  # the default fixup's RPATH shrink (patchelf) chokes on it ("null bytes") and
  # truncates it, and strip is likewise unnecessary. Skip both.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share $out/bin
    cp -a . $out/share/cns_v1.3_r9

    # Re-point the installed env scripts at the store. (csh shebangs were already
    # fixed tree-wide in postPatch; do NOT substituteInPlace anything under
    # ${cnsArch}/bin — those are symlinks to the ELF executable and
    # substituteInPlace truncates binaries at the first null byte.)
    for env in cns_solve_env cns_solve_env_sh; do
      substituteInPlace $out/share/cns_v1.3_r9/$env \
        --replace-fail "$builddir" "$out/share/cns_v1.3_r9"
    done

    # EVcouplings runs `cns` and pipes a *.inp script on stdin. The executable
    # needs the CNS environment (CNS_SOLVE + library paths) sourced first.
    cat > $out/bin/cns <<EOF
    #!/bin/sh
    . "$out/share/cns_v1.3_r9/cns_solve_env_sh"
    exec "$out/share/cns_v1.3_r9/${cnsArch}/bin/cns_solve" "\$@"
    EOF
    chmod +x $out/bin/cns
    runHook postInstall
  '';

  # Real smoke test: feed a trivial `stop` script and require the FFT3C startup
  # self-test to pass with no fatal error (the test that the -fopenmp flag broke).
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    log=$(printf 'stop\n' | $out/bin/cns 2>&1) || true
    echo "$log" | grep -q "FFT3C: Using" \
      || { echo "CNS FFT3C self-test did not pass:"; echo "$log" | tail -n 20; exit 1; }
    if echo "$log" | grep -qi "Fatal Error"; then
      echo "CNS reported a fatal error:"; echo "$log" | grep -i "Fatal Error"; exit 1
    fi
    echo "install check OK"
    runHook postInstallCheck
  '';

  # requireFile src behind a registration wall: no public URL to track, so the
  # update-packages workflow skips it during matrix discovery.
  passthru.skipUpdate = true;
  # requireFile: keep in `packages` but excluded from `nix flake check` builds.
  passthru.requireFile = true;
  passthru.category = "Sequence & Structure Analysis";

  meta = {
    description = "Crystallography & NMR System — macromolecular structure determination (EVcouplings fold engine)";
    homepage = "http://cns-online.org/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "cns";
  };
})
