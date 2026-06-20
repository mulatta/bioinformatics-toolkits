{
  lib,
  stdenv,
  python3Packages,
  requireFile,
  unzip,
  runCommand,
  autoPatchelfHook,
}:
let
  version = "4.0.2.0";

  # The distributed zip bundles one prebuilt wheel per (python, platform).
  # Select the wheel matching the current interpreter and host platform.
  pyTag = "cp${lib.replaceStrings [ "." ] [ "" ] python3Packages.python.pythonVersion}";

  platformTag =
    {
      x86_64-linux = "linux_x86_64";
      aarch64-linux = "linux_aarch64";
      aarch64-darwin = "macosx_11_0_arm64";
      x86_64-darwin = "macosx_12_0_x86_64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "nupack: unsupported platform ${stdenv.hostPlatform.system}");

  wheelName = "nupack-${version}-${pyTag}-${pyTag}-${platformTag}.whl";

  # Registration-walled download; user must add the zip to the store manually.
  zip = requireFile {
    name = "nupack-${version}.zip";
    hash = "sha256-4y/PqyqRsm+TKwMRMbLSCqkPKvndoCFMjkiq7QTSzVU=";
    url = "https://www.nupack.org/download/software";
    message = ''
      NUPACK requires free registration. Download nupack-${version}.zip from
      https://www.nupack.org and add it to the Nix store:
        nix-store --add-fixed sha256 nupack-${version}.zip
    '';
  };

  # Extract just our wheel; keep the .whl name so wheelUnpackPhase's stripHash
  # yields a valid filename for pip.
  wheel = runCommand wheelName { nativeBuildInputs = [ unzip ]; } ''
    unzip -j ${zip} "nupack-${version}/package/${wheelName}" -d unpacked
    mv "unpacked/${wheelName}" "$out"
  '';
in
python3Packages.buildPythonPackage {
  pname = "nupack";
  inherit version;
  format = "wheel";

  src = wheel;

  # cpp.so is a raw (non-manylinux) ELF linking libstdc++/libgcc_s; patch it.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dependencies = with python3Packages; [
    pyyaml
    scipy
    numpy
    pandas
    jinja2
  ];

  pythonImportsCheck = [ "nupack" ];

  # requireFile src behind a registration wall: no public URL to track, so the
  # update-packages workflow skips it during matrix discovery.
  passthru.skipUpdate = true;

  meta = {
    description = "Analysis and design of nucleic acid structures, devices, and systems";
    homepage = "https://www.nupack.org";
    license = lib.licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
