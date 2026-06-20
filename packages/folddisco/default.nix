{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "folddisco";
  version = "2-9375a2d";

  src = fetchFromGitHub {
    owner = "steineggerlab";
    repo = "folddisco";
    tag = finalAttrs.version;
    hash = "sha256-fguPo+o/lTzBbpnITM+eGZ6yrzguExsHececticz0Fk=";
  };

  cargoHash = "sha256-lJZaMo8kbkZtEd0LsA5AnufDEApIn/p+kuvUbl/rdYY=";

  # The default "foldcomp" feature compiles the vendored lib/foldcomp C++ FFI
  # via the cmake crate (cmake) and generates bindings (bindgenHook → libclang).
  nativeBuildInputs = [
    cmake
    rustPlatform.bindgenHook
  ];

  # build.rs drives cmake itself; the cmake setup hook must not hijack configure.
  dontUseCmakeConfigure = true;

  # build.rs derives the version from .git, absent in the sandbox; supply it so
  # `folddisco --version` reports the release instead of "unknown".
  env.FOLDDISCO_BUILD_VERSION = finalAttrs.version;

  passthru.category = "Protein Structure Search & Alignment";

  meta = {
    description = "Finding discontinuous motifs in protein structures";
    homepage = "https://github.com/steineggerlab/folddisco";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    mainProgram = "folddisco";
  };
})
