#!/usr/bin/env python3
"""Update interproscan to the latest release on the EBI FTP mirror.

InterProScan is distributed as a versioned tarball under
ftp.ebi.ac.uk/pub/software/unix/iprscan/5/<version>/, with no GitHub release
feed, so nix-update cannot track it. We scrape the directory index for the
newest version. The tarball is multi-GiB, so the hash (a download) is only
computed when a newer version actually exists.

Run from the repository root; rewrites packages/interproscan/default.nix.
"""

import re
import subprocess
import sys
import urllib.request
from pathlib import Path

INDEX = "https://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/"
TARBALL = INDEX + "{v}/interproscan-{v}-64-bit.tar.gz"
NIX = Path("packages/interproscan/default.nix")
VERSION_RE = re.compile(r"(\d+)\.(\d+)-(\d+)\.(\d+)")


def sh(cmd: list[str]) -> str:
    """Run a command and return stripped stdout."""
    return subprocess.run(
        cmd, check=True, text=True, capture_output=True
    ).stdout.strip()


def version_key(v: str) -> tuple[int, ...]:
    """Sortable key for a 'MAJOR.MINOR-DATA.REV' version string."""
    m = VERSION_RE.fullmatch(v)
    if m is None:
        sys.exit(f"unparseable version: {v}")
    return tuple(int(g) for g in m.groups())


def latest_version() -> str:
    """Return the newest version directory listed in the EBI index."""
    with urllib.request.urlopen(INDEX, timeout=60) as resp:  # noqa: S310 (https only)
        html = resp.read().decode()
    versions = {m.group(0) for m in VERSION_RE.finditer(html)}
    if not versions:
        sys.exit("no versions found in EBI index")
    return max(versions, key=version_key)


def prefetch_hash(version: str) -> str:
    """Compute the SRI hash of the release tarball (downloads it)."""
    base32 = sh(["nix-prefetch-url", "--type", "sha256", TARBALL.format(v=version)])
    return sh(["nix", "hash", "to-sri", "--type", "sha256", base32])


def replace_field(text: str, key: str, value: str) -> str:
    """Replace the first `key = "...";` assignment, asserting it changed."""
    new_text, n = re.subn(
        rf'({re.escape(key)} = ")[^"]*(";)', rf"\g<1>{value}\g<2>", text, count=1
    )
    if n != 1:
        sys.exit(f"could not rewrite field {key!r} in {NIX}")
    return new_text


def main() -> None:
    """Bump interproscan to the newest EBI release, if any."""
    text = NIX.read_text()
    current = re.search(r'version = "([^"]*)"', text)
    if current is None:
        sys.exit(f"no version field in {NIX}")

    latest = latest_version()
    if latest == current.group(1):
        print(f"interproscan already at {latest}")
        return

    sri = prefetch_hash(latest)
    text = replace_field(text, "version", latest)
    text = replace_field(text, "hash", sri)
    NIX.write_text(text)
    print(f"interproscan {current.group(1)} -> {latest}")


if __name__ == "__main__":
    main()
