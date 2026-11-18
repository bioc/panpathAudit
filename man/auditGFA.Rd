\name{auditGFA}
\alias{auditGFA}
\title{Audit FASTA sequences against GFA traversals}
\usage{
auditGFA(
  fasta,
  gfa,
  mapping = NULL,
  statistics = c("basic", "comprehensive"),
  threads = 1L,
  memoryMiB = 1024L,
  alignmentMaxCells = 10000000
)
}
\arguments{
\item{fasta}{The source sequences, as one of:
\itemize{
\item a \code{character()} vector of paths to one or more FASTA files,
plain or gzip-compressed, with no \code{NA} or empty strings;
\item a \code{Biostrings::DNAStringSet} of sequences already in memory,
treated as one source; every sequence must be named;
\item a \code{list} (or \code{Biostrings::DNAStringSetList}) in which each
element is a single path or a \code{DNAStringSet}, one element per
source.
}
Records are matched to GFA traversals by name, after applying
\code{mapping}. As in a FASTA header, a record's name is the first word of
its name, so a sequence named \code{"chr1 assembled"} matches \code{chr1}.
Each \code{DNAStringSet} is written to a temporary FASTA file in
\code{tempdir()} for the duration of the call, so it needs that much free
disk space; it is shown as \code{<DNAStringSet name>} (or its position) in
provenance and diagnostics. \pkg{Biostrings} is only needed for
\code{DNAStringSet} input.}
\item{gfa}{\code{character(1)}. Path to one GFA file, plain or
gzip-compressed.}
\item{mapping}{\code{NULL} (default), or a \code{data.frame} or
\code{DataFrame} with one row per source in \code{fasta} (one per path,
\code{DNAStringSet}, or list element), in the same order.
It says how each FASTA file's record names map to GFA path or walk names.
Columns:
\describe{
\item{\code{mode}}{Required. One of \code{"exact"} (use the record name
as is), \code{"pansn"} (\code{sample#haplotype#name}), or \code{"prefix"}
(\code{prefix} followed by the record name).}
\item{\code{sample}}{Sample name. Required for \code{"pansn"} rows.}
\item{\code{haplotype}}{Haplotype number, given as digits (e.g.
\code{"1"} or \code{1}). Required for \code{"pansn"} rows.}
\item{\code{prefix}}{Non-empty prefix string. Required for
\code{"prefix"} rows.}
}
Columns that a row's mode does not use may be omitted or left as \code{""}
or \code{NA}. With \code{NULL}, every file uses \code{"exact"}.}
\item{statistics}{\code{character(1)}. \code{"basic"} (default) reports
outcomes and digests only. \code{"comprehensive"} also aligns every
divergent pair and reports base-level statistics; see
\code{\link{auditStatistics}}.}
\item{threads}{\code{numeric(1)}. Number of worker threads; a positive
whole number. Default \code{1L}. Results do not depend on the thread
count.}
\item{memoryMiB}{\code{numeric(1)}. Limit, in MiB, on the memory used by
sequences held at the same time; a positive whole number. Default
\code{1024L}. A single sequence larger than the limit is still audited, on
its own, and is counted in \code{auditTelemetry(x)$oversized_contigs}.}
\item{alignmentMaxCells}{\code{numeric(1)}. Maximum number of alignment
matrix cells per divergent pair when \code{statistics = "comprehensive"}; a
positive whole number. Default \code{1e7}. If the limit is reached, that row
gets \code{alignment_status = "limit_exceeded"} and the audit continues.
Ignored when \code{statistics = "basic"}.}
}
\value{A \linkS4class{PanPathAuditResult}.}
\description{
Compares source sequences with named GFA \code{P} paths and coordinate-aware
\code{W} walks. Graph topology is not validated.
}
\details{
Gzip input is detected from file content. GFA \code{P} records must use blunt
overlaps (\code{*} or \code{0M}). \code{W} identifiers are formed as
\code{sample#haplotype#sequence}; their ranges are zero-based and half-open.

Use \code{mapping} when FASTA record names differ from the GFA path or walk
names, for example when walk names follow the PanSN convention
(\code{sample#haplotype#name}). See the \code{mapping} argument for the
supported modes and columns.

A running audit can be interrupted with Ctrl-C (or Esc in the R GUI). Worker
threads are stopped, and an R \code{interrupt} condition is signalled; no
partial result is returned.

Argument, input, and operational failures raise conditions with classes
\code{panpathAudit_argument_error}, \code{panpathAudit_input_error}, and
\code{panpathAudit_operational_error}. Each inherits from
\code{panpathAudit_error} and carries a \code{diagnostics} \code{DataFrame}.
Diagnostic positions are one-based.
}
\examples{
fasta <- system.file("extdata", "example.fa", package = "panpathAudit")
gfa <- system.file("extdata", "example.gfa", package = "panpathAudit")
result <- auditGFA(fasta, gfa)
auditOutcomes(result)
}
