{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
  hmmer,
  hh-suite,
  plmc,
  # Optional fold (3D structure) stage tools. These are non-free / not bundled,
  # so they are supplied by the user exactly like gemme's naccess, e.g.
  #   evcouplings.override { cns = <pkg>; psipred = <pkg>; maxcluster = <pkg>; }
  # The core pipeline (align / couplings / compare / mutate) needs none of them.
  cns ? null,
  psipred ? null,
  maxcluster ? null,
}:
let
  py = python3.pkgs;

  # EVcouplings 0.3.0 still uses the pre-0.18 ruamel.yaml API (RoundTripLoader,
  # safe_load, RoundTripDumper), removed in 0.18; nixpkgs ships 0.19. Pin 0.17.x
  # for this package so config loading works — this is exactly why upstream caps
  # the dependency at `ruamel.yaml<0.18`.
  ruamel-yaml-017 = py.ruamel-yaml.overridePythonAttrs (_: rec {
    version = "0.17.40";
    src = fetchPypi {
      pname = "ruamel.yaml";
      inherit version;
      hash = "sha256-YCS5hvBnZdSCtbB+CGzEtM0F3SLdy8dY+iPVSHPPMT0=";
    };
  });

  runtimeTools = [
    hmmer
    hh-suite
    plmc
  ]
  ++ lib.optional (cns != null) cns
  ++ lib.optional (psipred != null) psipred
  ++ lib.optional (maxcluster != null) maxcluster;
in
# buildPythonPackage (not buildPythonApplication) so this serves as BOTH a CLI and
# an importable library: the 4 console scripts land in $out/bin (wrapped with the
# tools on PATH), and `python3.withPackages (ps: [ evcouplings ])` exposes the
# evcouplings.* API for notebook/scripted use.
py.buildPythonPackage {
  pname = "evcouplings";
  # No 0.3.0 release tag yet; track the develop HEAD (PyPI is still on 0.2.1).
  version = "0.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "debbiemarkslab";
    repo = "EVcouplings";
    rev = "14c83457c6cfca8156aabe0615067447a2169791";
    hash = "sha256-bQZbr9hSjsJ4GCR2oQR4slhqYH4XZ0+aoWpWG0vAXRQ=";
  };

  build-system = [ py.hatchling ];

  dependencies =
    (with py; [
      billiard
      biopython
      bokeh
      click
      filelock
      jinja2
      matplotlib
      msgpack
      numba
      numpy
      pandas
      psutil
      requests
      scikit-learn
      scipy
      seaborn
      setuptools
    ])
    ++ [ ruamel-yaml-017 ];

  # External tools are invoked by bare name via subprocess (PATH-resolved; see
  # evcouplings/align/tools.py "put in PATH"). Put the core engines on PATH so a
  # config using bare tool names (jackhmmer/hmmbuild/hmmsearch/hhfilter/plmc)
  # works out of the box; optional fold tools join when supplied via override.
  makeWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath runtimeTools}" ];

  # No DB-free end-to-end run is possible in the sandbox (the align stage needs a
  # multi-GB sequence database), so verify the import chain instead — crucially
  # evcouplings.utils.config, which exercises the pinned ruamel.yaml API.
  pythonImportsCheck = [
    "evcouplings"
    "evcouplings.align"
    "evcouplings.couplings"
    "evcouplings.mutate"
    "evcouplings.utils.config"
  ];

  passthru.category = "Evolution & Variation";

  meta = {
    description = "Predict residue couplings, 3D structure and mutation effects from sequence coevolution";
    homepage = "https://github.com/debbiemarkslab/EVcouplings";
    # Code is MIT; the only non-MIT files are the bundled CNS input scripts
    # (*.inp, (c) Yale University), used solely by the optional fold stage.
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "evcouplings";
  };
}
