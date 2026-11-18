\name{panpathAudit-package}
\alias{panpathAudit-package}
\alias{panpathAudit}
\docType{package}
\title{Audit sequence preservation in GFA traversals}
\description{
Audits FASTA sequences against named GFA paths and walks without claiming to
validate graph topology.

For each traversal, \pkg{panpathAudit} reports whether the sequence spelled by
a GFA \code{P} path or coordinate-aware \code{W} walk is identical to its
source FASTA record. Every traversal gets SHA-256 and BLAKE3 digests of the
source and graph sequences, and divergent traversals also get the coordinates
of the first difference. Optionally, the package also computes base-level
comparison statistics. Links, overlaps beyond blunt joins, and connectivity are not
checked.
}
\details{
The main entry point is \code{\link{auditGFA}()}, which takes one or more FASTA
files (plain or gzip-compressed), one GFA file, and an optional mapping
between FASTA files and path or walk names. It returns a
\code{\linkS4class{PanPathAuditResult}} object, whose contents are read with
these accessors:
\itemize{
\item \code{\link{auditOutcomes}()}: one row per traversal, as a
\code{DataFrame}.
\item \code{\link{auditSummary}()}: counts and percentages per outcome
status.
\item \code{\link{auditStatistics}()}: base-level statistics when
\code{statistics = "comprehensive"}.
\item \code{\link{auditProvenance}()}: inputs, settings, and versions used.
\item \code{\link{auditTelemetry}()}: memory limit, peak tracked memory,
and thread count.
}

The native engine is a C++ port of the Rust command-line tool
\code{panpath-audit} (\url{https://github.com/gkanogiannis/panpath-audit}). See
\code{system.file("PROVENANCE.md", package = "panpathAudit")} for the port,
bundled third-party code, and example data.

The vignette gives a worked introduction:
\code{vignette("panpathAudit", package = "panpathAudit")}.
}
\author{
Anestis Gkanogiannis \email{anestis@gkanogiannis.com}

Maintainer: Anestis Gkanogiannis \email{anestis@gkanogiannis.com}
}
\references{
Gkanogiannis, A. (2026). Panpath-Audit: Sequence-Level Verification of
Embedded Pangenome Paths Against Source Assemblies. \emph{Preprints}.
\doi{10.20944/preprints202608.1872.v1}
}
\seealso{
\code{\link{auditGFA}} to run an audit;
\code{\linkS4class{PanPathAuditResult}} for the result class and its
accessors.

Package website and issue tracker:
\url{https://github.com/gkanogiannis/panpathAudit}
}
\examples{
fasta <- system.file("extdata", "example.fa", package = "panpathAudit")
gfa <- system.file("extdata", "example.gfa", package = "panpathAudit")
result <- auditGFA(fasta, gfa)
result
summary(result)
}
\keyword{package}
