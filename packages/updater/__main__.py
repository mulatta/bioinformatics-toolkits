#!/usr/bin/env python3
"""Update package definitions and optionally open one PR per package."""

import argparse
import json
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Package:
    name: str
    method: str


@dataclass(frozen=True)
class UpdateResult:
    package: Package
    success: bool
    changed: bool
    old_version: str | None = None
    new_version: str | None = None


def run_cmd(
    cmd: list[str],
    cwd: Path | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Run a command and capture output."""
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def get_flake_root() -> Path:
    """Find repository root from current checkout."""
    result = run_cmd(["git", "rev-parse", "--show-toplevel"], check=False)
    if result.returncode != 0:
        sys.exit("Error: not inside a git repository")
    return Path(result.stdout.strip())


def git_has_changes(cwd: Path) -> bool:
    """Return true when checkout has tracked or untracked changes."""
    result = run_cmd(["git", "status", "--porcelain"], cwd=cwd, check=False)
    return bool(result.stdout.strip())


def package_path(root: Path, package: str) -> Path:
    return root / "packages" / package


def custom_update_exists(root: Path, package: str) -> bool:
    return (package_path(root, package) / "update.py").exists()


def discover_packages(root: Path) -> list[Package]:
    """Discover updateable packages from flake metadata."""
    expr = """
      ps: builtins.filter
        (n: (ps.${n} ? version) && !(ps.${n}.passthru.skipUpdate or false))
        (builtins.attrNames ps)
    """
    result = run_cmd(
        ["nix", "eval", "--json", ".#packages.x86_64-linux", "--apply", expr],
        cwd=root,
    )
    names: list[str] = json.loads(result.stdout)
    return [
        Package(
            name=name,
            method="custom" if custom_update_exists(root, name) else "nix-update",
        )
        for name in sorted(names)
    ]


def flake_version(root: Path, package: str) -> str | None:
    """Evaluate package version from flake output."""
    result = run_cmd(
        ["nix", "eval", "--raw", f".#packages.x86_64-linux.{package}.version"],
        cwd=root,
        check=False,
    )
    if result.returncode == 0:
        return result.stdout.strip()
    return version_from_default_nix(root, package)


def version_from_default_nix(root: Path, package: str) -> str | None:
    """Fallback parser for packages that cannot evaluate."""
    default_nix = package_path(root, package) / "default.nix"
    if not default_nix.exists():
        return None
    match = re.search(r'\bversion\s*=\s*"([^"]+)"', default_nix.read_text())
    return match.group(1) if match else None


def run_nix_update(root: Path, package: str, dry_run: bool) -> bool:
    """Run nix-update for one package."""
    cmd = ["nix-update", "--flake", package]
    print(f"  Running: {' '.join(cmd)}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    result = run_cmd(cmd, cwd=root, check=False)
    if result.stdout:
        print(result.stdout.strip())
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.strip(), file=sys.stderr)
        return False
    return True


def run_custom_update(root: Path, package: str, dry_run: bool) -> bool:
    """Run package-local update.py from repository root."""
    script = package_path(root, package) / "update.py"
    cmd = [sys.executable, str(script)]
    print(f"  Running: {script.relative_to(root)}")

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    result = run_cmd(cmd, cwd=root, check=False)
    if result.stdout:
        print(result.stdout.strip())
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.strip(), file=sys.stderr)
        return False
    return True


def update_package(root: Path, package: Package, dry_run: bool) -> UpdateResult:
    """Update one package in the given checkout."""
    print(f"\nUpdating {package.name} ({package.method})")
    old_version = flake_version(root, package.name)

    if package.method == "custom":
        success = run_custom_update(root, package.name, dry_run)
    else:
        success = run_nix_update(root, package.name, dry_run)

    new_version = flake_version(root, package.name)
    changed = git_has_changes(root)
    return UpdateResult(package, success, changed, old_version, new_version)


def repo_owner(root: Path) -> str | None:
    """Return GitHub repository owner for PR head lookup."""
    result = run_cmd(
        ["gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"],
        cwd=root,
        check=False,
    )
    if result.returncode != 0:
        return None
    repo = result.stdout.strip()
    if "/" not in repo:
        return None
    return repo.split("/", 1)[0]


def open_pr_exists(root: Path, owner: str | None, branch: str) -> bool:
    """Check whether an open PR already exists for branch."""
    head = f"{owner}:{branch}" if owner else branch
    result = run_cmd(
        [
            "gh",
            "pr",
            "list",
            "--head",
            head,
            "--state",
            "open",
            "--json",
            "number",
            "--jq",
            ".[0].number // empty",
        ],
        cwd=root,
        check=False,
    )
    return bool(result.stdout.strip())


def create_pr_for_package(
    root: Path,
    package: Package,
    owner: str | None,
    dry_run: bool,
) -> bool:
    """Update one package in an isolated git worktree and create a PR."""
    branch = f"update/{package.name}"
    print(f"\nCreating PR for {package.name}")

    if open_pr_exists(root, owner, branch):
        print(f"  Open PR for {branch} already exists, skipping")
        return True

    if dry_run:
        print("  (dry-run, skipping)")
        return True

    with tempfile.TemporaryDirectory() as tmpdir:
        worktree = Path(tmpdir) / "worktree"
        result = run_cmd(
            ["git", "worktree", "add", "-B", branch, str(worktree), "origin/main"],
            cwd=root,
            check=False,
        )
        if result.returncode != 0:
            print(result.stderr.strip(), file=sys.stderr)
            return False

        try:
            return update_and_open_pr(worktree, package, branch)
        finally:
            run_cmd(
                ["git", "worktree", "remove", "--force", str(worktree)],
                cwd=root,
                check=False,
            )
            run_cmd(["git", "branch", "-D", branch], cwd=root, check=False)


def update_and_open_pr(worktree: Path, package: Package, branch: str) -> bool:
    """Run update in worktree, then commit, push, and open PR."""
    result = update_package(worktree, package, dry_run=False)
    if not result.success:
        print("  Update failed")
        return False

    if not result.changed:
        print("  No changes, already up to date")
        return True

    run_cmd(["nix", "fmt"], cwd=worktree)
    run_cmd(["git", "add", "-A"], cwd=worktree)

    old_version = result.old_version or "unknown"
    new_version = (
        flake_version(worktree, package.name) or result.new_version or "unknown"
    )
    title = f"{package.name}: update to {new_version}"
    body = f"Automated update of {package.name} from {old_version} to {new_version}."

    commit = run_cmd(
        [
            "git",
            "-c",
            "user.name=nixbot",
            "-c",
            "user.email=nixbot@users.noreply.github.com",
            "commit",
            "-m",
            title,
        ],
        cwd=worktree,
        check=False,
    )
    if commit.returncode != 0:
        print(commit.stderr.strip(), file=sys.stderr)
        return False

    push = run_cmd(["git", "push", "-f", "origin", branch], cwd=worktree, check=False)
    if push.returncode != 0:
        print(push.stderr.strip(), file=sys.stderr)
        return False

    pr = run_cmd(
        [
            "gh",
            "pr",
            "create",
            "--base",
            "main",
            "--head",
            branch,
            "--title",
            title,
            "--body",
            body,
            "--label",
            "auto-merge",
        ],
        cwd=worktree,
        check=False,
    )
    if pr.returncode != 0:
        print(pr.stderr.strip(), file=sys.stderr)
        return False

    print(f"  Created PR: {pr.stdout.strip()}")
    return True


def list_packages(packages: list[Package]) -> None:
    """Print discovered packages grouped by update method."""
    for method in ["custom", "nix-update"]:
        print(f"{method} packages:")
        for package in packages:
            if package.method == method:
                print(f"  - {package.name}")
        print()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--list", "-l", action="store_true")
    parser.add_argument("--package", "-p")
    parser.add_argument(
        "--pr", action="store_true", help="create PRs using git worktrees"
    )
    args = parser.parse_args()

    root = get_flake_root()
    packages = discover_packages(root)

    if args.package:
        packages = [package for package in packages if package.name == args.package]
        if not packages:
            print(f"Error: package {args.package!r} not found", file=sys.stderr)
            return 1

    if args.list:
        list_packages(packages)
        return 0

    owner = repo_owner(root) if args.pr else None
    failures = 0

    for package in packages:
        if args.pr:
            ok = create_pr_for_package(root, package, owner, args.dry_run)
        else:
            ok = update_package(root, package, args.dry_run).success
        failures += 0 if ok else 1

    print(f"\nResults: {len(packages) - failures} succeeded, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
