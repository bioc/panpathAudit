# Version of the Rust panpath-audit tool whose behaviour the C++ engine
# reproduces. Update this together with the "Rust reference tag" line in
# inst/PROVENANCE.md when the engine is re-synced with a newer Rust release;
# a test checks that the two agree.
.PANPATH_REFERENCE_VERSION <- "0.1.2"

.argument_error <- function(
    message,
    code = "INVALID_ARGUMENT",
    call = sys.call(-1L)
) {
    diagnostics <- DataFrame(
        category = "argument", code = code, message = message,
        path = NA_character_, line = NA_real_, identifier = NA_character_,
        position = NA_real_, symbol = NA_character_,
        details = SimpleList(list(list()))
    )
    condition <- structure(
        list(message = message, call = call, diagnostics = diagnostics),
        class = c(
            "panpathAudit_argument_error", "panpathAudit_error",
            "error", "condition"
        )
    )
    stop(condition)
}

.scalar_whole <- function(value, name, maximum = 2^53 - 1) {
    if (!is.numeric(value) || length(value) != 1L ||
        is.na(value) || !is.finite(value) ||
        value <= 0 || value != floor(value) || value > maximum) {
        .argument_error(sprintf("%s must be one positive whole number", name))
    }
    as.double(value)
}

.mapping_frame <- function(mapping, count) {
    if (is.null(mapping)) {
        return(data.frame(
            mode = rep("exact", count), sample = rep("", count),
            haplotype = rep("", count), prefix = rep("", count),
            stringsAsFactors = FALSE
        ))
    }
    if (!is.data.frame(mapping) && !is(mapping, "DataFrame"))
        .argument_error("mapping must be NULL, a data.frame, or a DataFrame")
    mapping <- as.data.frame(mapping, stringsAsFactors = FALSE)
    if (nrow(mapping) != count)
        .argument_error("mapping must have one row per FASTA")
    if (!"mode" %in% names(mapping)) {
        .argument_error("mapping must contain a mode column")
    }
    for (name in c("sample", "haplotype", "prefix"))
        if (!name %in% names(mapping)) mapping[[name]] <- ""
    mapping <- mapping[c("mode", "sample", "haplotype", "prefix")]
    mapping[] <- lapply(mapping, function(value) {
        value <- as.character(value)
        value[is.na(value)] <- ""
        value
    })
    if (any(!mapping$mode %in% c("exact", "pansn", "prefix")))
        .argument_error("mapping mode must be exact, pansn, or prefix")
    pansn <- mapping$mode == "pansn"
    invalid_pansn <- mapping$sample == "" |
        !grepl("^[0-9]+$", mapping$haplotype)
    if (any(pansn & invalid_pansn))
        .argument_error("PanSN mappings require a sample and numeric haplotype")
    if (any(mapping$mode == "prefix" & mapping$prefix == ""))
        .argument_error("prefix mappings require a non-empty prefix")
    mapping
}

.diagnostic_frame <- function(rows) {
    if (!length(rows)) {
        return(DataFrame(
            category = character(), code = character(), message = character(),
            path = character(), line = numeric(), identifier = character(),
            position = numeric(), symbol = character(), details = SimpleList()
        ))
    }
    field <- function(name, type) {
        values <- lapply(rows, `[[`, name)
        if (type == "character") {
            return(vapply(
                values,
                function(x) if (length(x)) x else NA_character_, ""
            ))
        }
        vapply(values, function(x) if (length(x)) x else NA_real_, 0)
    }
    DataFrame(
        category = field("category", "character"),
        code = field("code", "character"),
        message = field("message", "character"),
        path = field("path", "character"),
        line = field("line", "numeric"),
        identifier = field("identifier", "character"),
        position = field("position", "numeric"),
        symbol = field("symbol", "character"),
        details = SimpleList(lapply(rows, `[[`, "details"))
    )
}

# Normalize `fasta` into one entry per source. Each entry is either a file
# path or an in-memory DNAStringSet. Nothing is written to disk here, so that
# all arguments are validated before any temporary file is created.
.fasta_inputs <- function(fasta, call) {
    usage <- paste(
        "fasta must be a character vector of FASTA paths, a DNAStringSet,",
        "or a list of these"
    )
    if (is.character(fasta)) {
        if (!length(fasta) || anyNA(fasta) || any(!nzchar(fasta)))
            .argument_error(
                "fasta paths must be non-empty and not NA", call = call
            )
        return(as.list(fasta))
    }
    if (is(fasta, "DNAStringSet")) fasta <- list(fasta)
    else if (is(fasta, "DNAStringSetList")) fasta <- as.list(fasta)
    if (!is.list(fasta) || !length(fasta)) .argument_error(usage, call = call)
    for (index in seq_along(fasta)) {
        entry <- fasta[[index]]
        is_path <- is.character(entry) && length(entry) == 1L &&
            !is.na(entry) && nzchar(entry)
        if (!is_path && !is(entry, "DNAStringSet"))
            .argument_error(
                sprintf("%s; element %d is neither", usage, index),
                call = call
            )
        if (is(entry, "DNAStringSet")) {
            ids <- names(entry)
            if (length(entry) &&
                (is.null(ids) || anyNA(ids) || any(!grepl("\\S", ids))))
                .argument_error(
                    sprintf(
                        "DNAStringSet in fasta element %d must have %s",
                        index, "a non-empty name for every sequence"
                    ),
                    call = call
                )
            # A line break in a name would split the FASTA header when the
            # set is written out and silently change the sequence.
            if (any(grepl("[\r\n]", ids)))
                .argument_error(
                    sprintf(
                        "DNAStringSet in fasta element %d has %s",
                        index, "sequence names containing line breaks"
                    ),
                    call = call
                )
        }
    }
    fasta
}

# Turn the entries from .fasta_inputs() into paths the engine can read.
# DNAStringSet entries are written to temporary FASTA files; `labels` is what
# provenance and diagnostics show in place of those temporary paths.
.fasta_files <- function(inputs) {
    if (any(vapply(inputs, is, logical(1), "DNAStringSet")) &&
        !requireNamespace("Biostrings", quietly = TRUE)) {
        .argument_error(
            "the Biostrings package is required for DNAStringSet input",
            call = sys.call(-1L)
        )
    }
    entry_names <- names(inputs)
    paths <- labels <- character(length(inputs))
    temporary <- character()
    # If writing any set fails, remove the files already written; on success
    # the caller takes over cleanup.
    completed <- FALSE
    on.exit(if (!completed) unlink(temporary))
    for (index in seq_along(inputs)) {
        entry <- inputs[[index]]
        if (is.character(entry)) {
            paths[[index]] <- labels[[index]] <-
                normalizePath(path.expand(entry), mustWork = FALSE)
            next
        }
        file <- tempfile("panpathAudit-", fileext = ".fa")
        temporary <- c(temporary, file)
        Biostrings::writeXStringSet(entry, file)
        paths[[index]] <- normalizePath(file, mustWork = TRUE)
        name <- if (!is.null(entry_names) && nzchar(entry_names[[index]])) {
            entry_names[[index]]
        } else {
            as.character(index)
        }
        # Keep labels unique when list names repeat.
        if (sum(entry_names == name, na.rm = TRUE) > 1L)
            name <- sprintf("%s, element %d", name, index)
        labels[[index]] <- sprintf("<DNAStringSet %s>", name)
    }
    completed <- TRUE
    list(paths = paths, labels = labels, temporary = temporary)
}

.native_error <- function(rows, call, labels = NULL) {
    diagnostics <- .diagnostic_frame(rows)
    if (length(labels) && nrow(diagnostics)) {
        hit <- match(diagnostics$path, names(labels))
        diagnostics$path[!is.na(hit)] <- labels[hit[!is.na(hit)]]
    }
    operational <- any(diagnostics$category %in% c("operational", "internal"))
    class <- if (operational) {
        "panpathAudit_operational_error"
    } else {
        "panpathAudit_input_error"
    }
    message <- if (nrow(diagnostics)) {
        diagnostics$message[[1L]]
    } else {
        "audit failed"
    }
    condition <- structure(
        list(message = message, call = call, diagnostics = diagnostics),
        class = c(class, "panpathAudit_error", "error", "condition")
    )
    stop(condition)
}

.audit_result <- function(
    payload, fasta, gfa, mapping, statistics, threads,
    memoryMiB, alignmentMaxCells
) {
    counts <- unlist(payload$summary, use.names = TRUE)
    total <- sum(counts)
    summary <- list(
        counts = counts,
        percentages = if (total) {
            100 * counts / total
        } else {
            rep(NA_real_, length(counts))
        },
        total = total
    )
    provenance <- c(list(
        package_version = as.character(utils::packageVersion("panpathAudit")),
        reference_version = .PANPATH_REFERENCE_VERSION,
        fasta = fasta, gfa = gfa,
        mapping = DataFrame(mapping),
        statistics = statistics, threads = threads,
        memory_mib = memoryMiB, alignment_max_cells = alignmentMaxCells,
        topology_validated = FALSE
    ), payload$native_provenance)
    telemetry <- c(payload$telemetry, list(threads = threads))
    .PanPathAuditResult(
        payload$outcomes, summary, payload$statistics, provenance, telemetry
    )
}

#' Audit source sequences against GFA traversals
#'
#' Compares FASTA records with named GFA paths and coordinate-aware walks.
#' Graph topology is not validated.
#'
#' Gzip input is detected from file content. GFA `P` records must use blunt
#' overlaps (`*` or `0M`). `W` identifiers are formed as
#' `sample#haplotype#sequence` and use zero-based, half-open ranges.
#'
#' @param fasta Character vector of FASTA paths.
#' @param gfa One GFA path.
#' @param mapping Optional data frame with one row per FASTA. See Details.
#' @param statistics Either `"basic"` or `"comprehensive"`.
#' @param threads Positive worker count.
#' @param memoryMiB Positive tracked-memory limit in MiB.
#' @param alignmentMaxCells Positive comprehensive-alignment limit.
#' @return A `PanPathAuditResult`.
#' @details
#' Mapping modes are `exact`, `pansn`, and `prefix`. PanSN rows require
#' `sample` and numeric `haplotype`; prefix rows require `prefix`.
#'
#' Input failures raise `panpathAudit_input_error`; argument failures raise
#' `panpathAudit_argument_error`; operational failures raise
#' `panpathAudit_operational_error`. Each inherits from `panpathAudit_error`
#' and carries a `diagnostics` `DataFrame`.
#' @export
auditGFA <- function(
    fasta,
    gfa,
    mapping = NULL,
    statistics = c("basic", "comprehensive"),
    threads = 1L,
    memoryMiB = 1024L,
    alignmentMaxCells = 10000000
) {
    call <- match.call()
    inputs <- .fasta_inputs(fasta, call)
    if (!is.character(gfa) || length(gfa) != 1L || is.na(gfa) || !nzchar(gfa))
        .argument_error("gfa must be one non-empty path", call = call)
    statistics <- match.arg(statistics)
    threads <- .scalar_whole(threads, "threads", .Machine$integer.max)
    memoryMiB <- .scalar_whole(memoryMiB, "memoryMiB", (2^53 - 1) / 1024^2)
    alignmentMaxCells <- .scalar_whole(alignmentMaxCells, "alignmentMaxCells")
    mapping <- .mapping_frame(mapping, length(inputs))
    gfa <- normalizePath(path.expand(gfa), mustWork = FALSE)
    files <- .fasta_files(inputs)
    on.exit(unlink(files$temporary), add = TRUE)
    sources <- lapply(seq_along(files$paths), function(index) list(
        path = enc2utf8(files$paths[[index]]), mode = mapping$mode[[index]],
        sample = mapping$sample[[index]],
        haplotype = mapping$haplotype[[index]],
        prefix = mapping$prefix[[index]]
    ))
    payload <- .panpath_audit_native(list(
        sources = sources, gfa = enc2utf8(gfa), statistics = statistics,
        threads = threads, memoryBytes = memoryMiB * 1024^2,
        alignmentMaxCells = alignmentMaxCells,
        tempDir = enc2utf8(normalizePath(tempdir(), mustWork = TRUE))
    ))
    if (!identical(payload$state, "completed")) {
        labels <- files$labels
        names(labels) <- files$paths
        .native_error(payload$diagnostics, call, labels = labels)
    }
    .audit_result(
        payload, files$labels, gfa, mapping, statistics, threads,
        memoryMiB, alignmentMaxCells
    )
}
