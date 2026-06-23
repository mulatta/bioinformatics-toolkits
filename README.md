# bioinformatics-toolkits

Nix package registry for bioinformatics.

## Usage

Run a tool directly without installing:

```bash
nix run github:mulatta/bioinformatics-toolkits#foldseek -- --help
```

Or add the flake as an input and pull packages from `packages.<system>`.

Supported systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`.

## Available Packages

<!-- BEGIN GENERATED PACKAGE DOCS -->

### Protein Structure Search & Alignment

<details>
<summary><strong>folddisco</strong> - Finding discontinuous motifs in protein structures</summary>

- **License**: GPL-3.0-or-later
- **Homepage**: https://github.com/steineggerlab/folddisco
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#folddisco -- --help`
- **Nix**: [packages/folddisco/default.nix](packages/folddisco/default.nix)

</details>
<details>
<summary><strong>foldmason</strong> - Multiple protein structure alignment at scale with FoldMason</summary>

- **License**: GPL-3.0-or-later
- **Homepage**: https://github.com/steineggerlab/foldmason
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#foldmason -- --help`
- **Nix**: [packages/foldmason/default.nix](packages/foldmason/default.nix)

</details>
<details>
<summary><strong>foldseek</strong> - Fast and sensitive protein structure search</summary>

- **License**: GPL-3.0-or-later
- **Homepage**: https://github.com/steineggerlab/foldseek
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#foldseek -- --help`
- **Nix**: [packages/foldseek/default.nix](packages/foldseek/default.nix)

</details>
<details>
<summary><strong>maxcluster</strong> - Protein structure comparison and clustering</summary>

- **License**: unfree
- **Homepage**: https://www.sbg.bio.ic.ac.uk/~maxcluster/
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#maxcluster -- --help`
- **Nix**: [packages/maxcluster/default.nix](packages/maxcluster/default.nix)

</details>
<details>
<summary><strong>usalign</strong> - Universal structure alignment of monomeric and complex proteins and nucleic acids</summary>

- **License**: US-align license (permissive, BSD-like)
- **Homepage**: https://github.com/pylelab/USalign
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#usalign -- --help`
- **Nix**: [packages/usalign/default.nix](packages/usalign/default.nix)

</details>

### Protein Function Annotation

<details>
<summary><strong>interproscan</strong> - Genome-scale protein function classification (InterPro member-database scanner)</summary>

- **License**: Apache-2.0
- **Homepage**: https://www.ebi.ac.uk/interpro/about/interproscan/
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#interproscan -- --help`
- **Nix**: [packages/interproscan/default.nix](packages/interproscan/default.nix)

</details>

### Nucleic Acid Analysis & Design

<details>
<summary><strong>nupack</strong> - Analysis and design of nucleic acid structures, devices, and systems</summary>

- **License**: unfree
- **Homepage**: https://www.nupack.org
- **Usage**: `nix build github:mulatta/bioinformatics-toolkits#nupack`
- **Nix**: [packages/nupack/default.nix](packages/nupack/default.nix)

</details>

### Phylogenetics & Evolutionary Analysis

<details>
<summary><strong>consurf</strong> - Standalone ConSurf: evolutionary conservation of amino-acid/nucleotide positions, web-server equivalent</summary>

- **License**: ConSurf academic use (no upstream license file)
- **Homepage**: https://consurf.tau.ac.il
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#consurf -- --help`
- **Nix**: [packages/consurf/default.nix](packages/consurf/default.nix)

</details>
<details>
<summary><strong>rate4site</strong> - Detect conserved amino-acid sites by computing the relative evolutionary rate for each site</summary>

- **License**: GPL-2.0-or-later
- **Homepage**: https://www.tau.ac.il/~itaymay/cp/rate4site.html
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#rate4site -- --help`
- **Nix**: [packages/rate4site/default.nix](packages/rate4site/default.nix)

</details>

### Sequence & Structure Analysis

<details>
<summary><strong>biotite</strong> - Comprehensive library for computational molecular biology</summary>

- **License**: BSD-3-Clause
- **Homepage**: https://www.biotite-python.org
- **Usage**: `nix build github:mulatta/bioinformatics-toolkits#biotite`
- **Nix**: [packages/biotite/default.nix](packages/biotite/default.nix)

</details>
<details>
<summary><strong>cns</strong> - Crystallography & NMR System — macromolecular structure determination (EVcouplings fold engine)</summary>

- **License**: unfree
- **Homepage**: http://cns-online.org/
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#cns -- --help`
- **Nix**: [packages/cns/default.nix](packages/cns/default.nix)

</details>
<details>
<summary><strong>psipred</strong> - PSIPRED V4 protein secondary structure prediction</summary>

- **License**: unfree
- **Homepage**: https://github.com/psipred/psipred
- **Usage**: `nix build github:mulatta/bioinformatics-toolkits#psipred`
- **Nix**: [packages/psipred/default.nix](packages/psipred/default.nix)

</details>

### Coevolution & Variant Effect

<details>
<summary><strong>evcouplings</strong> - Predict residue couplings, 3D structure and mutation effects from sequence coevolution</summary>

- **License**: MIT
- **Homepage**: https://github.com/debbiemarkslab/EVcouplings
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#evcouplings -- --help`
- **Nix**: [packages/evcouplings/default.nix](packages/evcouplings/default.nix)

</details>
<details>
<summary><strong>gemme</strong> - Predict mutational effects from evolutionary conservation and global epistasis</summary>

- **License**: MIT
- **Homepage**: http://www.lcqb.upmc.fr/GEMME/
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#gemme -- --help`
- **Nix**: [packages/gemme/default.nix](packages/gemme/default.nix)

</details>
<details>
<summary><strong>plmc</strong> - Infer Potts models (couplings) from a multiple sequence alignment by pseudo-likelihood maximization</summary>

- **License**: MIT
- **Homepage**: https://github.com/debbiemarkslab/plmc
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#plmc -- --help`
- **Nix**: [packages/plmc/default.nix](packages/plmc/default.nix)

</details>

### Protein Stability Prediction

<details>
<summary><strong>thermompnn</strong> - Predict ddG stability changes of protein point mutants with a ProteinMPNN-based GNN</summary>

- **License**: MIT
- **Homepage**: https://github.com/Kuhlman-Lab/ThermoMPNN
- **Usage**: `nix run github:mulatta/bioinformatics-toolkits#thermompnn -- --help`
- **Nix**: [packages/thermompnn/default.nix](packages/thermompnn/default.nix)

</details>

<!-- END GENERATED PACKAGE DOCS -->

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Run `nix fmt` before committing
4. Submit a pull request

## License

Individual tools are licensed under their respective licenses.

The Nix packaging code in this repository is licensed under MIT.
