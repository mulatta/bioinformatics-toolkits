{
  lib,
  config,
  stdenv,
  fetchFromGitHub,
  python3,
  makeWrapper,
  # CUDA follows the ecosystem knob, exactly like nixpkgs' torch
  # (cudaSupport ? config.cudaSupport): off by default, on when the caller builds
  # with config.cudaSupport, or per-package via
  #   thermompnn.override { cudaSupport = true; }
  # custom_inference.py selects the device at runtime
  #   device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
  # so the same wrapper transparently uses the GPU whenever the env's torch is a
  # CUDA build, and the CPU otherwise — no separate entrypoint needed.
  cudaSupport ? config.cudaSupport,
}:
let
  # We assemble a withPackages env, so torch cannot just be a package input:
  # pytorch-lightning / torchmetrics each propagate their own torch, and mixing a
  # CPU torch with a CUDA torch in one env collides on files. Override torch
  # across the whole interpreter so every dependent resolves the *same* build.
  python = python3.override {
    packageOverrides =
      _: super:
      lib.optionalAttrs cudaSupport {
        # Mirror nixpkgs' torchWithCuda. Referencing super.torchWithCuda directly
        # recurses (it is defined via the fixpoint's self.torch, which we replace).
        torch = super.torch.override {
          cudaSupport = true;
          triton = super.triton-cuda;
          rocmSupport = false;
        };
      };
  };

  # Inference pulls in this whole chain at import time:
  #   custom_inference -> train_thermompnn (imports wandb, pytorch_lightning,
  #   torchmetrics at module top level) -> datasets (numpy, biopython) -> ...
  # wandb is unused for inference but imported unconditionally, so it must be
  # present or the script fails to load (loud, not silent).
  pythonEnv = python.withPackages (
    ps: with ps; [
      torch
      pytorch-lightning
      torchmetrics
      omegaconf
      biopython
      pandas
      numpy
      tqdm
      wandb
    ]
  );
in
stdenv.mkDerivation (_finalAttrs: {
  pname = "thermompnn";
  # No upstream tags/releases; track the main-branch HEAD by commit date.
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "Kuhlman-Lab";
    repo = "ThermoMPNN";
    rev = "2b04fd370e399911b1fa5848112cc9013f084110";
    hash = "sha256-93j6fd/jmHIarolUlbUM4ugHXrBOn3adnZ7SRHf+FXc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # A clone-and-run repo (no setup.py): install the source tree and wrap the
  # site-saturation inference script. The trained checkpoints are committed to
  # the repo directly (not git-LFS), so the default Megascale model ships in $src.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/thermompnn $out/bin
    cp -r . $out/share/thermompnn/

    # local.yaml hardcodes the authors' cluster path; custom_inference.py reads it
    # to locate the bundled ProteinMPNN vanilla weights
    # (<thermompnn_dir>/vanilla_model_weights/v_48_020.pt). Repoint it at the
    # installed tree, or model construction dies with FileNotFoundError.
    substituteInPlace $out/share/thermompnn/local.yaml \
      --replace-fail '/proj/kuhl_lab/ThermoMPNN' $out/share/thermompnn

    # custom_inference.py sits in analysis/ and imports both repo-root modules
    # (datasets, train_thermompnn, protein_mpnn_utils) and analysis/ siblings
    # (SSM, thermompnn_benchmarking), so both dirs go on PYTHONPATH. We also pin
    # --model_path to the bundled default checkpoint; a user-supplied --model_path
    # appears later on the command line and wins (argparse keeps the last value).
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/thermompnn \
      --add-flags $out/share/thermompnn/analysis/custom_inference.py \
      --add-flags "--model_path $out/share/thermompnn/models/thermoMPNN_default.pt" \
      --prefix PYTHONPATH : "$out/share/thermompnn:$out/share/thermompnn/analysis"

    runHook postInstall
  '';

  # Real-data smoke test: run the wrapped predictor on a tiny but genuine
  # structure (test-fragment.pdb = first six residues of crambin, PDB 1CRN) and
  # assert it emits a non-empty site-saturation CSV. This exercises the full
  # import chain, the bundled checkpoint, and ProteinMPNN featurization on CPU.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    cp ${./test-fragment.pdb} test.pdb
    $out/bin/thermompnn --pdb test.pdb --chain A --out_dir out
    out_csv=$(echo out/ThermoMPNN_inference_*.csv)
    test -s "$out_csv" || { echo "ThermoMPNN produced no/empty output CSV"; exit 1; }
    echo "install check OK: $(wc -l < "$out_csv") rows in $out_csv"

    runHook postInstallCheck
  '';

  passthru = {
    category = "Protein Stability Prediction";
    # Tracks a moving branch; bump with packages/thermompnn/update.py.
  };

  meta = {
    description = "Predict ddG stability changes of protein point mutants with a ProteinMPNN-based GNN";
    homepage = "https://github.com/Kuhlman-Lab/ThermoMPNN";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "thermompnn";
  };
})
