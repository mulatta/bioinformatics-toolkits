#!/usr/bin/env python3
"""Update usalign to the latest commit on pylelab/USalign's default branch.

USalign publishes no releases or tags, so nix-update cannot track it. We follow
the default branch HEAD, keep the upstream-style YYYYMMDD version (derived from
the commit date), and refresh the pinned rev + source hash.

Run from the repository root; rewrites packages/usalign/default.nix in place.
"""

import json
import re
import subprocess
import sys
from pathlib import Path

OWNER = "pylelab"
REPO = "USalign"
NIX = Path("packages/usalign/default.nix")


def sh(cmd: list[str]) -> str:
    """Run a command and return stripped stdout."""
    return subprocess.run(
        cmd, check=True, text=True, capture_output=True
    ).stdout.strip()


def latest_commit() -> tuple[str, str]:
    """Return (sha, YYYYMMDD) for the default branch HEAD via the GitHub API."""
    branch = json.loads(sh(["gh", "api", f"repos/{OWNER}/{REPO}"]))["default_branch"]
    commit = json.loads(sh(["gh", "api", f"repos/{OWNER}/{REPO}/commits/{branch}"]))
    sha = commit["sha"]
    # committer date is ISO-8601 (e.g. 2026-05-27T...); take the date part.
    date = commit["commit"]["committer"]["date"][:10].replace("-", "")
    return sha, date


def prefetch_hash(sha: str) -> str:
    """Compute the SRI hash of the unpacked source archive for a commit."""
    url = f"https://github.com/{OWNER}/{REPO}/archive/{sha}.tar.gz"
    base32 = sh(["nix-prefetch-url", "--unpack", "--type", "sha256", url])
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
    """Bump usalign to the newest upstream commit, if any."""
    text = NIX.read_text()
    current_rev = re.search(r'rev = "([^"]*)"', text)
    if current_rev is None:
        sys.exit(f"no rev field in {NIX}")

    sha, date = latest_commit()
    if sha == current_rev.group(1):
        print(f"usalign already at {sha[:9]} ({date})")
        return

    sri = prefetch_hash(sha)
    text = replace_field(text, "version", date)
    text = replace_field(text, "rev", sha)
    text = replace_field(text, "hash", sri)
    NIX.write_text(text)
    print(f"usalign -> {date} ({sha[:9]})")


if __name__ == "__main__":
    main()
