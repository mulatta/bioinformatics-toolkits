{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  writeShellApplication,
  temurin-bin-11,
  perl,
  python3,
  gawk,
  gnused,
  gnugrep,
  coreutils,
  which,
  gzip,
  zlib,
  pcre2,
  bzip2,
  gfortran,
  unzip,
  zip,
}:
let
  version = "5.78-109.0";

  # Heavy half: unpack the ~6.6 GiB tarball (~49 GiB on disk), patch ELF
  # interpreters/shebangs and bake the HMM indexes. A separate derivation so
  # iterating on the launcher does not re-copy and re-patch the whole data tree.
  interproscan-unwrapped = stdenv.mkDerivation (finalAttrs: {
    pname = "interproscan-unwrapped";
    inherit version;

    src = fetchurl {
      url = "https://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/${finalAttrs.version}/interproscan-${finalAttrs.version}-64-bit.tar.gz";
      hash = "sha256-AC2Z7qS8yXZfRMVkwpwnmijEsS8Eh5x1t9bKUu9mq8A=";
    };

    nativeBuildInputs = [
      autoPatchelfHook
      # patchShebangs needs the interpreters the bundled scripts hardcode.
      perl
      python3
      # Rewrite the /bin/bash constant in the bundled jars (postFixup).
      unzip
      zip
    ];

    # Shared libraries the dynamically linked bundled binaries need:
    #   pcre2    prosite pfsearchV3/pfscanV3
    #   bzip2    cdd/rpsblast
    #   gfortran prosite psa2msa
    buildInputs = [
      stdenv.cc.cc.lib
      zlib
      pcre2
      bzip2
      gfortran.cc.lib
    ];

    dontConfigure = true;
    dontBuild = true;

    # We invoke autoPatchelf explicitly in postFixup (see below); disable the
    # automatic pass so the whole ~49 GiB tree is not scanned a second time.
    dontAutoPatchelf = true;

    installPhase = ''
      runHook preInstall

      dest=$out/share/interproscan
      mkdir -p "$dest"
      # unpackPhase already extracted to the source root; move (not copy) the tree.
      shopt -s dotglob
      mv -- * "$dest"/
      shopt -u dotglob
      patchShebangs "$dest"

      runHook postInstall
    '';

    postFixup = ''
      # Patch the bundled ELF binaries now (not via the automatic pass, which is
      # disabled) so the bundled hmmpress is runnable for setup.py's index step.
      autoPatchelf -- "$out"

      dest=$out/share/interproscan
      ( cd "$dest" && ${python3.interpreter} setup.py -f interproscan.properties )

      # InterProScan's process monitor shells out to a hardcoded /bin/bash, which
      # NixOS lacks (it ships /bin/sh). Every command issued that way is POSIX-sh
      # compatible, so rewrite the CONSTANT_Utf8 in the two classes that use it
      # (length 9 -> 7 is safe: pool entries are length-prefixed, no absolute
      # offsets), then repack the affected class.
      for spec in \
        "lib/interproscan-io-${finalAttrs.version}.jar uk/ac/ebi/interpro/scan/io/cli/CommandLineConversationMonitor.class" \
        "lib/interproscan-util-${finalAttrs.version}.jar uk/ac/ebi/interpro/scan/util/Utilities.class"; do
        set -- $spec
        jar="$dest/$1"
        cls="$2"
        tmp=$(mktemp -d)
        unzip -q "$jar" "$cls" -d "$tmp"
        perl -i -0777pe 's{\x01\x00\x09/bin/bash}{\x01\x00\x07/bin/sh}g' "$tmp/$cls"
        chmod u+w "$jar" # bundled jars arrive read-only
        ( cd "$tmp" && zip -q "$jar" "$cls" )
        rm -rf "$tmp"
        if unzip -p "$jar" "$cls" | grep -q "/bin/bash"; then
          echo "patch-binbash: /bin/bash still present in $cls" >&2
          exit 1
        fi
      done

      # Bake a properties template for the launcher: bin/data point at the store,
      # while the writable temp/jms paths carry an @work@ placeholder the launcher
      # swaps for the per-invocation scratch dir (they must be ABSOLUTE, else
      # InterProScan creates them under the caller's working directory).
      # --replace-fail aborts the build if upstream renames any of these keys.
      install -m644 "$dest/interproscan.properties" "$dest/interproscan-nix.properties"
      substituteInPlace "$dest/interproscan-nix.properties" \
        --replace-fail 'bin.directory=bin' "bin.directory=$dest/bin" \
        --replace-fail 'data.directory=data' "data.directory=$dest/data" \
        --replace-fail 'temporary.file.directory=temp/' 'temporary.file.directory=@work@/temp/' \
        --replace-fail 'jms.broker.temp.directory=activemq-data/' 'jms.broker.temp.directory=@work@/activemq-data/'
    '';

    meta = {
      description = "InterProScan member-database binaries and data (unwrapped)";
      homepage = "https://www.ebi.ac.uk/interpro/about/interproscan/";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
    };
  });
in
# The store install is read-only, but InterProScan cd's into it and writes there
# (a bundled LevelDB's LOCK, temp, logs). Per invocation, assemble a writable view
# in a scratch dir and feed InterProScan a properties file with absolute store
# bin/data paths and absolute scratch temp/jms paths.
writeShellApplication {
  name = "interproscan";
  # Upstream requires Java 11 and tests the AdoptOpenJDK/Temurin builds, not
  # nixpkgs' source-built openjdk.
  # https://interproscan-docs.readthedocs.io/en/v5/InstallationRequirements.html
  runtimeInputs = [
    temurin-bin-11
    perl
    python3
    gawk
    gnused
    gnugrep
    coreutils
    which
    gzip
  ];
  text = ''
    ips="${interproscan-unwrapped}/share/interproscan"
    work="$(mktemp -d "''${TMPDIR:-/tmp}/interproscan.XXXXXX")"
    trap 'rm -rf "$work"' EXIT

    # Heavy, read-only parts are symlinked; the small writable parts are copied.
    # interproscan.sh is copied (not symlinked) so its `cd "$(dirname "$0")"`
    # lands in the writable view instead of following the link into the store.
    for entry in "$ips"/*; do
      name="$(basename "$entry")"
      case "$name" in
        work)
          cp -rs "$entry" "$work/work"
          chmod -R u+w "$work/work"
          # Only the two LevelDBs need to be writable (for their LOCK file).
          for db in idb/iprEntryDB kvs/idb/entryDB; do
            rm -r "$work/work/$db"
            cp -r --no-preserve=mode "$ips/work/$db" "$work/work/$db"
          done
          ;;
        interproscan.sh)
          cp "$entry" "$work/interproscan.sh"
          chmod +x "$work/interproscan.sh"
          ;;
        interproscan.properties) : ;; # generated below from interproscan-nix.properties
        *) ln -s "$entry" "$work/$name" ;;
      esac
    done

    # Point @work@ in the baked template at this invocation's scratch dir, giving
    # InterProScan absolute writable temp/jms paths (so they never land under the
    # caller's working directory).
    conf="$work/interproscan.properties"
    sed "s|@work@|$work|g" "$ips/interproscan-nix.properties" >"$conf"
    export INTERPROSCAN_CONF="$conf"

    # Do not cd: interproscan.sh records $PWD as the user dir (to resolve relative
    # -i/-o paths) before cd'ing into the view itself.
    exec "$work/interproscan.sh" "$@"
  '';

  passthru = {
    inherit version;
    unwrapped = interproscan-unwrapped;
  };

  meta = {
    description = "Genome-scale protein function classification (InterPro member-database scanner)";
    homepage = "https://www.ebi.ac.uk/interpro/about/interproscan/";
    license = lib.licenses.asl20;
    # Prebuilt 64-bit Linux binaries only; PANTHER analysis needs extra work.
    platforms = [ "x86_64-linux" ];
    mainProgram = "interproscan";
  };
}
