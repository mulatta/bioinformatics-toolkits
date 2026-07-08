{
  lib,
  stdenv,
  fetchurl,
  perl,
}:
stdenv.mkDerivation {
  pname = "rate4site";
  version = "3.0.0";

  # Upstream rate4site is unmaintained and its distribution channels have rotted
  # (the author's page ships an older "3.2" snapshot stuck at a 2.01 banner; the
  # Rostlab FTP is dead). The Debian Med team's GPL release is the maintained
  # lineage: properly versioned (banner "3.0.0"), getopt CLI, and the exact code
  # standalone ConSurf runs (its bundled prebuilt produces byte-identical output
  # to this source). Pinned to Debian's immutable, hash-verified snapshot, which
  # was uploaded by an upstream developer (gyachdav@rostlab.org).
  src = fetchurl {
    url = "https://snapshot.debian.org/file/837fb82c4ac368ebc64a5d8697706be3b0679829";
    name = "rate4site-3.0.0.orig.tar.gz";
    hash = "sha256-X3SBMbwtEDg8NcMUGoNe+k7B5wiM2diXDoAkAhqlCaw=";
  };

  # pod2man builds the man page during make.
  nativeBuildInputs = [ perl ];

  # 2013-era C++ predates modern gcc/clang language defaults.
  env.CXXFLAGS = "-O2 -std=gnu++98 -fpermissive -w";

  enableParallelBuilding = true;

  # Standard autotools install ships two binaries: `rate4site` and
  # `rate4site_doublerep`. Per the upstream Makefile the primary `rate4site` is
  # the one built with -DDOUBLEREP (extended-range floats that avoid likelihood
  # underflow); it is what ConSurf's web server runs and what produces the
  # canonical conservation scores. `rate4site_doublerep` is the plain build.

  passthru = {
    category = "Evolution & Variation";
    # Frozen upstream: 3.0.0 is the last release and the orig tarball is an
    # immutable snapshot, so there is nothing for the auto-updater to track.
    skipUpdate = true;
  };

  meta = {
    description = "Detect conserved amino-acid sites by computing the relative evolutionary rate for each site";
    homepage = "https://www.tau.ac.il/~itaymay/cp/rate4site.html";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
    mainProgram = "rate4site";
  };
}
