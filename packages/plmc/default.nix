{
  lib,
  stdenv,
  fetchFromGitHub,
  llvmPackages,
  # Parallelise the pseudo-likelihood gradient with OpenMP (upstream's
  # `all-openmp` target). On by default to match nixpkgs' multithreaded-by-
  # default convention; the build stays bit-reproducible. Parallel float
  # reductions are not bitwise-deterministic at runtime, so disable this (or set
  # OMP_NUM_THREADS=1) when you need reproducible numerics.
  openmpSupport ? true,
}:
# plmc infers undirected graphical models (Potts models) from a multiple sequence
# alignment via pseudo-likelihood maximization — the coupling-inference engine
# behind EVcouplings' "couplings" stage and EVmutation. Small standalone C
# program with no dependencies beyond libm.
stdenv.mkDerivation (_finalAttrs: {
  pname = "plmc";
  # No upstream tags/releases; track the master HEAD by commit date.
  version = "0-unstable-2023-01-21";

  src = fetchFromGitHub {
    owner = "debbiemarkslab";
    repo = "plmc";
    rev = "18c9e55e3bd2f14f4968be19a807b401996c929a";
    hash = "sha256-3P69lrNWTlv4fZekHajt7zeqcphXZDc0IyRC264bjaE=";
  };

  # gcc's -fopenmp pulls in its own libgomp; clang needs the standalone libomp.
  buildInputs = lib.optional (openmpSupport && stdenv.cc.isClang) llvmPackages.openmp;

  # The bundled makefile hardcodes `-msse4.2` (x86-only) in every target. The
  # sources use no x86 intrinsics, so it is purely a codegen flag — compile
  # directly and add it only on x86_64, keeping aarch64 builds working.
  buildPhase = ''
    runHook preBuild
    $CC src/lib/twister.c src/lib/lbfgs.c src/plm.c src/inference.c src/weights.c src/main.c \
      -o plmc -std=c99 -O3 ${lib.optionalString stdenv.hostPlatform.isx86_64 "-msse4.2"} \
      ${lib.optionalString openmpSupport "-fopenmp"} -lm
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 plmc $out/bin/plmc
    runHook postInstall
  '';

  # Real-data smoke test: infer a model for the bundled DHFR protein alignment
  # (few iterations to stay fast) and assert the parameter file is written.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/plmc -o test.params -le 16.0 -lh 0.01 -m 2 -g -f DYR_ECOLI example/protein/DHFR.a2m
    test -s test.params || { echo "plmc wrote no parameter file"; exit 1; }
    echo "install check OK: $(stat -c%s test.params) bytes of params"
    runHook postInstallCheck
  '';

  passthru.category = "Evolution & Variation";

  meta = {
    description = "Infer Potts models (couplings) from a multiple sequence alignment by pseudo-likelihood maximization";
    homepage = "https://github.com/debbiemarkslab/plmc";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "plmc";
  };
})
