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
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "foldmason";
  version = "4-dd3c235";

  src = fetchFromGitHub {
    owner = "steineggerlab";
    repo = "foldmason";
    rev = finalAttrs.version;
    # Vendors foldseek (which vendors mmseqs); submodules are only regression
    # tests and a broken empty-URL kompute entry — not needed for build.
    hash = "sha256-HG23uTL1JCEvfKRoieurcAN6U03Kkndy2mN/G9JEocM=";
  };

  postPatch = ''
    patchShebangs lib/foldseek/lib/mmseqs/cmake/xxdi.pl
    # Remove deprecated cmake policy unsupported by modern cmake
    substituteInPlace CMakeLists.txt lib/foldseek/CMakeLists.txt \
      --replace-fail 'cmake_policy(SET CMP0060 OLD)' ""
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
    cargo
    rustc
    perl
  ];

  buildInputs = [
    zlib
    bzip2
    llvmPackages.openmp
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
  ];

  passthru.category = "Structure Analysis";

  meta = {
    description = "Multiple protein structure alignment at scale with FoldMason";
    homepage = "https://github.com/steineggerlab/foldmason";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "foldmason";
  };
})
