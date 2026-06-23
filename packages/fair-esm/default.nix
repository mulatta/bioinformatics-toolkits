{
  lib,
  stdenv,
  python3,
  fetchFromGitHub,
}:
# ESM-2 protein language model, as a library (`import esm`). Weights download at
# runtime to ~/.cache/torch/hub. Device follows the torch input (override torch
# for CUDA); upstream is archived, so the rev is final.
let
  py = python3.pkgs;
in
py.buildPythonPackage (_finalAttrs: {
  pname = "fair-esm";
  # Final commit past the v2.0.0 tag (repo archived).
  version = "2.0.0-unstable-2023-06-27";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "facebookresearch";
    repo = "esm";
    rev = "2b369911bb5b4b0dda914521b9475cad1656b2ac";
    hash = "sha256-p82UipKQYSFEuCiZijzUlInqwXhXrbiZwcNLBUzLXE0=";
  };

  build-system = [ py.setuptools ];

  postPatch = ''
    # torch >= 2.6 defaults weights_only=True, rejecting the pickled checkpoints.
    substituteInPlace esm/pretrained.py \
      --replace-fail 'map_location="cpu"' 'map_location="cpu", weights_only=False'
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    # extract.py only checks CUDA; add MPS for Apple Silicon GPUs.
    substituteInPlace scripts/extract.py \
      --replace-fail \
        'torch.cuda.is_available() and not args.nogpu' \
        '(torch.cuda.is_available() or torch.backends.mps.is_available()) and not args.nogpu' \
      --replace-fail \
        'model = model.cuda()' \
        'model = model.to("mps" if torch.backends.mps.is_available() else "cuda")' \
      --replace-fail \
        'toks = toks.to(device="cuda", non_blocking=True)' \
        'toks = toks.to(device="mps" if torch.backends.mps.is_available() else "cuda", non_blocking=True)'
  '';

  dependencies = [ py.torch ];

  optional-dependencies = {
    inverse-folding = [
      py.biotite
      py.scipy
    ];
  };

  # Tests download multi-GB weights; import-check instead.
  doCheck = false;
  pythonImportsCheck = [ "esm" ];

  # Archived upstream: nothing to update to.
  passthru.skipUpdate = true;
  passthru.category = "Sequence & Structure Analysis";

  meta = {
    description = "Evolutionary Scale Modeling (ESM): pretrained protein language models";
    homepage = "https://github.com/facebookresearch/esm";
    changelog = "https://github.com/facebookresearch/esm/releases/tag/v2.0.0";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
