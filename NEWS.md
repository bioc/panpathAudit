# panpathAudit NEWS

## panpathAudit 0.99.3

- `auditGFA()` accepts a `Biostrings::DNAStringSet`, or a list mixing FASTA
  paths and `DNAStringSet` objects, as `fasta`. Biostrings is a new
  suggested dependency.
- The result accessors (`auditOutcomes()` and others) raise a clear
  `panpathAudit_argument_error` when given anything other than a
  `PanPathAuditResult`.
- Document argument types and defaults in `?auditGFA`, the `mapping`
  columns, and how to interrupt a running audit; expand `?panpathAudit`.
- Credit the authors of the bundled BLAKE3 and SHA-256 code in `Authors@R`,
  add provenance headers to the vendored sources, and record the licenses
  used (CC0-1.0 and 0BSD).

## panpathAudit 0.99.2

- Change license to MIT

## panpathAudit 0.99.1

- Add R-universe CI test and mention license file in description

## panpathAudit 0.99.0

- Initial Bioconductor submission.
- Audits FASTA against GFA `P` paths and coordinate-aware `W` walks.
- Supports exact, PanSN, and prefix mappings, gzip input, digests, and optional
  base-level statistics.
