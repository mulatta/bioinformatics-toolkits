#!/usr/bin/env python3
"""Generate markdown documentation for all packages and update README.md.

Package metadata is the single source of truth: this script evaluates
generate-package-docs.nix, renders a collapsible <details> block per package,
and rewrites the region between the marker comments in README.md.
"""

import json
import subprocess
import sys
from pathlib import Path

BEGIN_MARKER = "<!-- BEGIN GENERATED PACKAGE DOCS -->"
END_MARKER = "<!-- END GENERATED PACKAGE DOCS -->"

FLAKE_REF = "github:mulatta/bioinformatics-toolkits"

Metadata = dict[str, str | bool | None]


def get_all_packages_metadata() -> dict[str, Metadata]:
    """Get metadata for all packages using a single nix eval."""
    nix_file = Path(__file__).parent / "generate-package-docs.nix"

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
    "Protein Structure Search & Alignment",
    "Protein Function Annotation",
    "Nucleic Acid Analysis & Design",
    "Phylogenetics & Evolutionary Analysis",
    "Uncategorized",
]


def generate_all_docs() -> str:
    """Generate documentation grouped by category, packages sorted by name."""
    all_metadata = get_all_packages_metadata()

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


def update_readme(readme_path: Path) -> bool:
    """Update README.md with generated docs. Returns True if modified."""
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

    generated_docs = generate_all_docs()

    new_content = (
        content[: begin_idx + len(BEGIN_MARKER)]
        + "\n\n"
        + generated_docs
        + "\n\n"
        + content[end_idx:]
    )

    if new_content == content:
        return False

    readme_path.write_text(new_content)
    return True


def main() -> None:
    """Run the main documentation generation process."""
    readme_path = Path(__file__).parent.parent / "README.md"

    if not readme_path.exists():
        print(f"Error: README.md not found at {readme_path}", file=sys.stderr)
        sys.exit(1)

    if update_readme(readme_path):
        print(f"Updated {readme_path}")
    else:
        print(f"No changes to {readme_path}")


if __name__ == "__main__":
    main()
