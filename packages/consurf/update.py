#!/usr/bin/env python3
"""Update the ConSurf standalone to the latest commit on Barak19/stand_alone_consurf.

The standalone is "v1.00" (Yariv et al. 2023) but the repo carries no tags, so
track its default-branch HEAD by commit date, like the upstream ConSurf pipelines
themselves (which pull HEAD). Each bump stays pinned to a specific commit.

Run from the repository root; rewrites packages/consurf/default.nix in place.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

OWNER = "Barak19"
REPO = "stand_alone_consurf"
NIX = Path("packages/consurf/default.nix")


def sh(cmd: list[str]) -> str:
    """Run a command and return stripped stdout."""
    return subprocess.run(
        cmd, check=True, text=True, capture_output=True
    ).stdout.strip()


def latest_commit() -> tuple[str, str]:
    """Return (sha, YYYY-MM-DD) for the default-branch HEAD via the GitHub API."""
    branch = json.loads(sh(["gh", "api", f"repos/{OWNER}/{REPO}"]))["default_branch"]
    commit = json.loads(sh(["gh", "api", f"repos/{OWNER}/{REPO}/commits/{branch}"]))
    return commit["sha"], commit["commit"]["committer"]["date"][:10]


def prefetch_hash(sha: str) -> str:
    """Compute the SRI hash of the unpacked source archive for a commit."""
    url = f"https://github.com/{OWNER}/{REPO}/archive/{sha}.tar.gz"
    base32 = sh(["nix-prefetch-url", "--unpack", "--type", "sha256", url])
    return sh(
        ["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32]
    )


def replace_field(text: str, key: str, value: str) -> str:
    """Replace the first `key = "...";` assignment, asserting it changed."""
    new_text, n = re.subn(
        rf'({re.escape(key)} = ")[^"]*(";)', rf"\g<1>{value}\g<2>", text, count=1
    )
    if n != 1:
        sys.exit(f"could not rewrite field {key!r} in {NIX}")
    return new_text


def main() -> None:
    """Bump the ConSurf standalone to the newest upstream commit, if any."""
    text = NIX.read_text()
    current_rev = re.search(r'rev = "([^"]*)"', text)
    if current_rev is None:
        sys.exit(f"no rev field in {NIX}")

    sha, date = latest_commit()
    if sha == current_rev.group(1):
        print(f"consurf already at {sha[:9]} ({date})")
        return

    sri = prefetch_hash(sha)
    text = replace_field(text, "version", f"1.00-unstable-{date}")
    text = replace_field(text, "rev", sha)
    text = replace_field(text, "hash", sri)
    NIX.write_text(text)
    print(f"consurf -> 1.00-unstable-{date} ({sha[:9]})")


if __name__ == "__main__":
    main()
