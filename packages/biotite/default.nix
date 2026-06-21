{
  lib,
  python3Packages,
  fetchFromGitHub,
  rustPlatform,
  cargo,
  rustc,
}:
let
  # Runtime dependency split out of biotite; absent from nixpkgs, so vendor it
  # here. Pure Cython, no Rust.
  biotraj = python3Packages.buildPythonPackage (finalAttrs: {
    pname = "biotraj";
    version = "1.2.2";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "biotite-dev";
      repo = "biotraj";
      tag = "v${finalAttrs.version}";
      hash = "sha256-N2MOgrlebfX+0Men73EsDDjV3MLBqT8CbIZpFsLgw9M=";
    };

    # Version is dynamic via setuptools-scm, which needs a .git that
    # fetchFromGitHub strips; pin it explicitly.
    env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

    build-system = with python3Packages; [
      setuptools
      setuptools-scm
      cython
      numpy
    ];

    dependencies = with python3Packages; [
      numpy
      scipy
    ];

    # Tests need trajectory data files not shipped in the sdist.
    doCheck = false;
    pythonImportsCheck = [ "biotraj" ];

    meta = {
      description = "Basic trajectory file format functionality for Biotite; forked from MDTraj";
      homepage = "https://github.com/biotite-dev/biotraj";
      license = lib.licenses.lgpl21Plus;
      platforms = lib.platforms.unix;
    };
  });
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "biotite";
  version = "1.7.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "biotite-dev";
    repo = "biotite";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FS5eACe7sQLxzPiyVobZ7dyzKovMutFJhs5qZlmi+7A=";
  };

  # Since 1.x biotite ships a Rust extension (pyo3) alongside the Cython one.
  # Upstream gitignores Cargo.lock (Rust library convention) and resolves crates
  # fresh on every build, so carry our own pinned lock for reproducibility. It is
  # regenerated on version bumps by the package's update.py (plain nix-update
  # cannot, as the lock must match the new Cargo.toml).
  cargoDeps = rustPlatform.importCargoLock { lockFile = ./Cargo.lock; };

  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
    # puccinialin only downloads a Rust toolchain when cargo is missing; we
    # provide one, so drop both its unconditional import and its build-system
    # requirement (otherwise the no-isolation build flags it as missing).
    substituteInPlace setup.py \
      --replace-fail "from puccinialin import setup_rust" ""
    substituteInPlace pyproject.toml \
      --replace-fail '"puccinialin", ' ""
  '';

  env.SETUPTOOLS_SCM_PRETEND_VERSION = finalAttrs.version;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
    setuptools-rust
    cython
  ];

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    cargo
    rustc
  ];

  dependencies = [
    biotraj
  ]
  ++ (with python3Packages; [
    numpy
    requests
    msgpack
    networkx
    packaging
  ]);

  # Tests pull large reference datasets at runtime.
  doCheck = false;
  pythonImportsCheck = [
    "biotite"
    "biotite.sequence"
    "biotite.structure"
  ];

  passthru.category = "Sequence & Structure Analysis";

  meta = {
    description = "Comprehensive library for computational molecular biology";
    homepage = "https://www.biotite-python.org";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.unix;
  };
})
