#!/usr/bin/env python3
"""Update biotite to the latest upstream release.

biotite ships a Rust extension but gitignores Cargo.lock, so nix-update cannot
handle it: a version bump needs a freshly resolved lock for the new Cargo.toml.
This script bumps the version + source hash and regenerates the pinned
Cargo.lock the build vendors via importCargoLock.

The biotraj runtime dependency is pinned separately in default.nix and updated
by hand (it rarely moves); this script touches only biotite itself.

Run from the repository root; rewrites packages/biotite/default.nix and
packages/biotite/Cargo.lock in place.
"""

import json
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

OWNER = "biotite-dev"
REPO = "biotite"
PKG = Path("packages/biotite")
NIX = PKG / "default.nix"
LOCK = PKG / "Cargo.lock"


def sh(cmd: list[str]) -> str:
    """Run a command and return stripped stdout."""
    return subprocess.run(
        cmd, check=True, text=True, capture_output=True
    ).stdout.strip()


def latest_version() -> str:
    """Return the newest stable release version (tag without the leading 'v')."""
    release = json.loads(sh(["gh", "api", f"repos/{OWNER}/{REPO}/releases/latest"]))
    return release["tag_name"].lstrip("v")


def prefetch_hash(tag: str) -> str:
    """Compute the SRI hash of the unpacked tag tarball."""
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz"
    base32 = sh(["nix-prefetch-url", "--unpack", "--type", "sha256", url])
    return sh(["nix", "hash", "to-sri", "--type", "sha256", base32])


def regenerate_lock(tag: str) -> None:
    """Fetch the tag source and write a freshly resolved Cargo.lock."""
    url = f"https://github.com/{OWNER}/{REPO}/archive/refs/tags/{tag}.tar.gz"
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp) / "src.tar.gz"
        urllib.request.urlretrieve(url, archive)  # noqa: S310 (trusted https)
        with tarfile.open(archive) as tar:
            tar.extractall(tmp, filter="data")
        src = next(p for p in Path(tmp).iterdir() if p.is_dir())
        # cargo is not in the dev shell; pull it on demand.
        subprocess.run(
            [
                "nix",
                "shell",
                "nixpkgs#cargo",
                "--command",
                "cargo",
                "generate-lockfile",
            ],
            cwd=src,
            check=True,
        )
        LOCK.write_text((src / "Cargo.lock").read_text())


def replace_biotite_field(text: str, pattern: str, value: str) -> str:
    """Replace a field inside the biotite block (not biotraj's), asserting one hit."""
    new_text, n = re.subn(
        pattern, rf"\g<1>{value}\g<2>", text, count=1, flags=re.DOTALL
    )
    if n != 1:
        sys.exit(f"could not rewrite {pattern!r} in {NIX}")
    return new_text


def main() -> None:
    """Bump biotite to the newest release, regenerating the vendored lock."""
    text = NIX.read_text()
    current = re.search(r'pname = "biotite";\s*version = "([^"]*)"', text)
    if current is None:
        sys.exit(f"no biotite version field in {NIX}")

    version = latest_version()
    if version == current.group(1):
        print(f"biotite already at {version}")
        return

    sri = prefetch_hash(f"v{version}")
    # Scope both rewrites to biotite: biotraj's version/hash precede it in the file.
    text = replace_biotite_field(
        text, r'(pname = "biotite";\s*version = ")[^"]*(")', version
    )
    text = replace_biotite_field(text, r'(repo = "biotite";.*?hash = ")[^"]*(")', sri)
    NIX.write_text(text)

    regenerate_lock(f"v{version}")
    print(f"biotite -> {version}")


if __name__ == "__main__":
    main()
