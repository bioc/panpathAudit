# Native engine provenance

The initial engine was ported from `panpath-audit` and preserves its 0.1.2
behavioral contract.

- Rust repository commit : `ad06a3a20987c2ef5c6eef84bd19b4a44cf86ce9`
- Rust repository: <https://github.com/gkanogiannis/panpath-audit>
- Rust reference tag: `v0.1.2`
- Package port date: 2026-08-20

Current R/C++ package and Rust reference versions are independent. The engine validates sequence correspondence, not graph topology.

# Port and third-party provenance

The native engine in `src/` is a C++ port of the Rust implementation at the
commit above. `panpath-audit` was released under Apache-2.0 and is now
dual-licensed as MIT OR Apache-2.0. The package maintainer is its sole author
and copyright holder, and distributes the C++ port here under the MIT option.

The package bundles two third-party C implementations in `src/vendor/`. Both
are unmodified from upstream apart from a provenance header added to each
file. Each header gives the upstream URL, version and license.

| Component | Files | Upstream | Version | Copyright holders | License used here |
| --- | --- | --- | --- | --- | --- |
| BLAKE3 | `src/vendor/blake3/` | <https://github.com/BLAKE3-team/BLAKE3> (`c/`) | 1.8.2 (commit `df610ddc3b93841ffc59a87e3da659a15910eb46`) | Jack O'Connor, Samuel Neves | CC0-1.0 (`inst/third-party/BLAKE3-LICENSE-CC0`) |
| SHA-256 | `src/vendor/sha256/` | <https://github.com/amosnier/sha-2> | commit `b29613850d6e54e7159197ef42c7d22d012b6367` | Alain Mosnier | 0BSD (`inst/third-party/SHA256-LICENSE.md`) |

BLAKE3 is offered upstream under CC0-1.0, Apache-2.0, or Apache-2.0 with
LLVM-exception. The SHA-256 code is offered under the Unlicense or the
Zero-Clause BSD license. panpathAudit uses the CC0-1.0 option for BLAKE3
and the 0BSD option for SHA-256. Both are permissive and compatible with
the package's MIT license.

# Use of AI assistance

OpenAI Codex and Anthropic Claude were both used during development of
this package:

- **C++ engine (`src/`, excluding `src/vendor/`)**: AI-assisted port of the
  Rust `panpath-audit` engine.
- **Tests (`tests/`)**: AI-assisted.
- **Documentation** (vignette, README, man pages, NEWS): AI-assisted.
- **R code (`R/`)**: mostly written by the maintainer, with some AI
  assistance.
- **Vendored code (`src/vendor/`)**: unmodified upstream BLAKE3 and SHA-256
  sources, not AI-generated.

The maintainer reviewed all AI-assisted code and text. The package passes `R CMD check` and `BiocCheck`. The
maintainer takes responsibility for the package's correctness and
maintenance.

# Example data provenance

The FASTA and GFA files in `inst/extdata` are synthetic. Reproduce them from
the package root with `Rscript inst/scripts/make-extdata.R`. No external data
or preprocessing is involved.
