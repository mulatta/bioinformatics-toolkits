{
  lib,
  stdenv,
  fetchurl,
}:
# MUSCLE 3.8.31 — the legacy release whose CLI is `muscle -in IN -clw -out OUT`.
# JET2 (and thus GEMME's homolog-retrieval modes) shells out with exactly those
# flags, which the rewritten MUSCLE 5 in nixpkgs no longer accepts. This is a
# private build for GEMME, not a general muscle package.
stdenv.mkDerivation {
  pname = "muscle";
  version = "3.8.31";

  # drive5's direct links have rotted; the Debian Med team's DFSG-repacked orig
  # tarball on the immutable snapshot archive is the maintained source.
  src = fetchurl {
    url = "https://snapshot.debian.org/archive/debian/20210101T000000Z/pool/main/m/muscle/muscle_3.8.31+dfsg.orig.tar.xz";
    hash = "sha256-oOitNMxbnv9u2TJAFkqf1EvzsEYQacw2gwHT/CcdPok=";
  };

  buildPhase = ''
    runHook preBuild
    # Compile exactly the file list upstream's ./mk uses — globbing *.cpp would
    # drag in dead files (e.g. redblack.cpp) that fail on modern compilers. The
    # 2010-era C++ needs the relaxed dialect/flags. Subshell keeps the cd local.
    (
      cd src
      srcs=$(grep "^CPPNames=" mk | sed "s/CPPNames='//;s/'$//" | tr ' ' '\n' | sed 's/$/.cpp/')
      g++ -O3 -msse2 -mfpmath=sse -D_FILE_OFFSET_BITS=64 -DNDEBUG=1 -fpermissive -w \
        -std=gnu++98 $srcs -o muscle
    )
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 src/muscle $out/bin/muscle
    runHook postInstall
  '';

  meta = {
    description = "MUSCLE 3.8.31 multiple sequence alignment (legacy -in/-clw/-out CLI)";
    homepage = "https://drive5.com/muscle/";
    license = lib.licenses.publicDomain;
    # -msse2/-mfpmath=sse are x86-specific.
    platforms = [ "x86_64-linux" ];
    mainProgram = "muscle";
  };
}
