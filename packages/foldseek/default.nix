{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  cargo,
  rustc,
  perl,
  zlib,
  bzip2,
  llvmPackages,
  config,
  cudaSupport ? config.cudaSupport or false,
  cudaPackages ? { },
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "foldseek";
  version = "10-941cd33";

  src = fetchFromGitHub {
    owner = "steineggerlab";
    repo = "foldseek";
    rev = finalAttrs.version;
    # Dependencies (mmseqs, prostt5) are vendored; submodules are only
    # regression tests and a broken empty-URL entry — not needed for build.
    hash = "sha256-tZ0oeYPlTXvr/NR7djEvdbuF2K2bMGKC+9FFgsZgY38=";
  };

  postPatch = ''
    patchShebangs lib/mmseqs/cmake/xxdi.pl
    patchShebangs cmake/xxdi.pl
    # Remove deprecated cmake policy unsupported by modern cmake
    substituteInPlace CMakeLists.txt \
      --replace-fail 'cmake_policy(SET CMP0060 OLD)' ""
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    cargo
    rustc
    perl
  ]
  ++ lib.optionals cudaSupport [
    cudaPackages.cuda_nvcc
  ];

  buildInputs = [
    zlib
    bzip2
    llvmPackages.openmp
  ]
  ++ lib.optionals cudaSupport [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];

  cmakeFlags = [
    # vendored mmseqs requires cmake_minimum_required(<3.5)
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    "-DHAVE_AVX2=1"
  ]
  ++ lib.optionals stdenv.hostPlatform.isAarch64 [
    "-DHAVE_ARM8=1"
  ]
  ++ lib.optionals cudaSupport [
    "-DENABLE_CUDA=1"
    "-DCMAKE_CUDA_ARCHITECTURES=75;80;86;89;90"
  ];

  passthru = {
    inherit cudaSupport;
  };

  meta = {
    description = "Fast and sensitive protein structure search";
    homepage = "https://github.com/steineggerlab/foldseek";
    license = lib.licenses.gpl3Plus;
    platforms = if cudaSupport then lib.platforms.linux else lib.platforms.unix;
    mainProgram = "foldseek";
  };
})
