#!/usr/bin/env python3
"""Generate markdown documentation for all packages and update README.md.

Package metadata is the single source of truth: this script loads evaluated
metadata, renders a collapsible <details> block per package, and rewrites the
region between the marker comments in README.md.
"""

import argparse
import difflib
import json
import subprocess
import sys
from pathlib import Path

BEGIN_MARKER = "<!-- BEGIN GENERATED PACKAGE DOCS -->"
END_MARKER = "<!-- END GENERATED PACKAGE DOCS -->"

FLAKE_REF = "github:mulatta/bioinformatics-toolkits"

Metadata = dict[str, str | bool | None]


def get_all_packages_metadata(metadata_json: Path | None = None) -> dict[str, Metadata]:
    """Get metadata for all packages from JSON or a single nix eval."""
    if metadata_json is not None:
        data = json.loads(metadata_json.read_text())
    else:
        nix_file = Path(__file__).parent / "package-docs-metadata-from-flake.nix"

        try:
            result = subprocess.run(
                ["nix", "eval", "--json", "--file", str(nix_file)],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            print(f"Error running nix eval: {e}", file=sys.stderr)
            if e.stderr:
                print(f"stderr: {e.stderr}", file=sys.stderr)
            raise

        data = json.loads(result.stdout)

    # Drop packages that failed to evaluate or opted out (null values).
    return {k: v for k, v in data.items() if v is not None}


def generate_package_doc(package: str, metadata: Metadata) -> str:
    """Generate markdown documentation for a single package."""
    description = metadata.get("description", "No description available")
    lines = [
        "<details>",
        f"<summary><strong>{package}</strong> - {description}</summary>",
        "",
        f"- **License**: {metadata.get('license', 'Check package')}",
    ]

    homepage = metadata.get("homepage")
    if homepage:
        lines.append(f"- **Homepage**: {homepage}")

    # Runnable packages document `nix run`; library-only packages document the
    # build output instead.
    if metadata.get("mainProgram"):
        lines.append(f"- **Usage**: `nix run {FLAKE_REF}#{package} -- --help`")
    else:
        lines.append(f"- **Usage**: `nix build {FLAKE_REF}#{package}`")

    lines.append(
        f"- **Nix**: [packages/{package}/default.nix](packages/{package}/default.nix)"
    )

    readme_path = Path(f"packages/{package}/README.md")
    if readme_path.exists():
        lines.append(
            f"- **Documentation**: See [packages/{package}/README.md]"
            f"(packages/{package}/README.md) for detailed usage"
        )

    lines += ["", "</details>"]
    return "\n".join(lines)


# Display order for category sections; any other category falls to the end.
CATEGORY_ORDER = [
    "Structure Analysis",
    "Sequence Analysis & Design",
    "Evolution & Variation",
    "Libraries",
    "Uncategorized",
]


def generate_all_docs(all_metadata: dict[str, Metadata]) -> str:
    """Generate documentation grouped by category, packages sorted by name."""
    by_category: dict[str, list[str]] = {}
    for package in sorted(all_metadata):
        category = all_metadata[package].get("category", "Uncategorized")
        by_category.setdefault(str(category), []).append(package)

    ordered = [c for c in CATEGORY_ORDER if c in by_category]
    ordered += sorted(c for c in by_category if c not in CATEGORY_ORDER)

    sections = []
    for category in ordered:
        entries = [
            generate_package_doc(p, all_metadata[p]) for p in by_category[category]
        ]
        sections.append(f"### {category}\n\n" + "\n".join(entries))
    return "\n\n".join(sections)


def rendered_readme(
    readme_path: Path, all_metadata: dict[str, Metadata]
) -> tuple[str, str]:
    """Return current README content and generated replacement."""
    content = readme_path.read_text()

    begin_idx = content.find(BEGIN_MARKER)
    end_idx = content.find(END_MARKER)

    if begin_idx == -1 or end_idx == -1:
        print(f"Error: Could not find markers in {readme_path}", file=sys.stderr)
        print(f"  Expected: {BEGIN_MARKER}", file=sys.stderr)
        print(f"  And: {END_MARKER}", file=sys.stderr)
        sys.exit(1)

    if end_idx < begin_idx:
        print("Error: END marker appears before BEGIN marker", file=sys.stderr)
        sys.exit(1)

    generated_docs = generate_all_docs(all_metadata)

    new_content = (
        content[: begin_idx + len(BEGIN_MARKER)]
        + "\n\n"
        + generated_docs
        + "\n\n"
        + content[end_idx:]
    )
    return content, new_content


def update_readme(readme_path: Path, all_metadata: dict[str, Metadata]) -> bool:
    """Update README.md with generated docs. Returns True if modified."""
    content, new_content = rendered_readme(readme_path, all_metadata)

    if new_content == content:
        return False

    readme_path.write_text(new_content)
    return True


def check_readme(readme_path: Path, all_metadata: dict[str, Metadata]) -> None:
    """Verify README.md already matches generated docs."""
    content, new_content = rendered_readme(readme_path, all_metadata)

    if new_content == content:
        print(f"No changes to {readme_path}")
        return

    diff = difflib.unified_diff(
        content.splitlines(keepends=True),
        new_content.splitlines(keepends=True),
        fromfile=str(readme_path),
        tofile=f"{readme_path} (generated)",
    )
    print(
        "README.md package docs are stale; run scripts/generate-package-docs.py",
        file=sys.stderr,
    )
    print("".join(diff), file=sys.stderr)
    sys.exit(1)


def main() -> None:
    """Run the main documentation generation process."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if README.md does not match generated package docs",
    )
    parser.add_argument(
        "--metadata-json",
        type=Path,
        help="read package metadata from JSON instead of running nix eval",
    )
    args = parser.parse_args()

    readme_path = Path(__file__).parent.parent / "README.md"

    if not readme_path.exists():
        print(f"Error: README.md not found at {readme_path}", file=sys.stderr)
        sys.exit(1)

    all_metadata = get_all_packages_metadata(args.metadata_json)

    if args.check:
        check_readme(readme_path, all_metadata)
    elif update_readme(readme_path, all_metadata):
        print(f"Updated {readme_path}")
    else:
        print(f"No changes to {readme_path}")


if __name__ == "__main__":
    main()
