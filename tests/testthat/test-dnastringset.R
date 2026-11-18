test_that("a DNAStringSet gives the same outcomes as the FASTA file", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(
        c(">s1", "ACGT", ">s2 description", "ACGA"),
        c("S\t1\tAC", "S\t2\tGT", "P\ts1\t1+,2+\t*", "P\ts2\t1+,2+\t*")
    )
    sequences <- Biostrings::readDNAStringSet(case$fasta)
    from_file <- outcome_frame(auditGFA(case$fasta, case$gfa))
    in_memory <- auditGFA(sequences, case$gfa)
    expect_equal(outcome_frame(in_memory), from_file)
    expect_equal(outcome_frame(in_memory)$status, c("IDENTICAL", "DIVERGENT"))
    expect_equal(auditProvenance(in_memory)$fasta, "<DNAStringSet 1>")
})

test_that("lists can mix paths and DNAStringSets, with mappings", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(
        c(">chr1", "ACGT"),
        c("S\t1\tACGT", "S\t2\tTTGG",
            "P\tchr1\t1+\t*", "P\thap#chr2\t2+\t*")
    )
    second <- Biostrings::DNAStringSet(c(chr2 = "TTGG"))
    mapping <- data.frame(mode = c("exact", "prefix"), prefix = c("", "hap#"))
    result <- auditGFA(
        list(case$fasta, other = second), case$gfa, mapping = mapping
    )
    rows <- outcome_frame(result)
    expect_equal(rows$identifier, c("chr1", "hap#chr2"))
    expect_equal(rows$status, c("IDENTICAL", "IDENTICAL"))
    expect_equal(rows$source_index, c(1, 2))
    expect_equal(
        auditProvenance(result)$fasta,
        c(normalizePath(case$fasta), "<DNAStringSet other>")
    )

    as_list <- Biostrings::DNAStringSetList(
        Biostrings::DNAStringSet(c(chr1 = "ACGT")), second
    )
    rows <- outcome_frame(auditGFA(as_list, case$gfa, mapping = mapping))
    expect_equal(rows$status, c("IDENTICAL", "IDENTICAL"))
})

test_that("temporary FASTA files are removed", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(">s1\nACGT", "S\t1\tACGT\nP\ts1\t1+\t*")
    sequences <- Biostrings::DNAStringSet(c(s1 = "ACGT"))
    pattern <- "^panpathAudit-.*\\.fa$"
    before <- list.files(tempdir(), pattern)
    auditGFA(sequences, case$gfa)
    expect_identical(list.files(tempdir(), pattern), before)
    bad <- Biostrings::DNAStringSet(c(s1 = "ACGT", s1 = "ACGT"))
    expect_error(auditGFA(bad, case$gfa), class = "panpathAudit_input_error")
    expect_identical(list.files(tempdir(), pattern), before)
})

test_that("repeated list names still give distinct labels", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(">s1\nACGT",
        c("S\t1\tACGT", "P\ts1\t1+\t*", "P\ts2\t1+\t*"))
    sets <- list(
        x = Biostrings::DNAStringSet(c(s1 = "ACGT")),
        x = Biostrings::DNAStringSet(c(s2 = "ACGT"))
    )
    labels <- auditProvenance(auditGFA(sets, case$gfa))$fasta
    expect_equal(
        labels, c("<DNAStringSet x, element 1>", "<DNAStringSet x, element 2>")
    )
})

test_that("temporary files are removed if writing a later set fails", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(">s1\nACGT", "S\t1\tACGT\nP\ts1\t1+\t*")
    write <- Biostrings::writeXStringSet
    calls <- 0L
    local_mocked_bindings(
        writeXStringSet = function(x, filepath, ...) {
            calls <<- calls + 1L
            if (calls > 1L) stop("simulated write failure")
            write(x, filepath, ...)
        },
        .package = "Biostrings"
    )
    set <- Biostrings::DNAStringSet(c(s1 = "ACGT"))
    pattern <- "^panpathAudit-.*\\.fa$"
    before <- list.files(tempdir(), pattern)
    expect_error(auditGFA(list(set, set), case$gfa), "simulated write failure")
    expect_equal(calls, 2L)
    expect_identical(list.files(tempdir(), pattern), before)
})

test_that("input errors report the DNAStringSet, not a temporary path", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(">s1\nACGT", "S\t1\tACGT\nP\ts1\t1+\t*")
    duplicated <- Biostrings::DNAStringSet(c(s1 = "ACGT", s1 = "ACGT"))
    error <- captured_error(auditGFA(duplicated, case$gfa))
    expect_s3_class(error, "panpathAudit_input_error")
    expect_true("DUPLICATE_SEQUENCE_IDENTIFIER" %in% error$diagnostics$code)
    expect_true("<DNAStringSet 1>" %in% error$diagnostics$path)
})

test_that("invalid fasta arguments are rejected before any file is written", {
    skip_if_not_installed("Biostrings")
    case <- audit_case(">s1\nACGT", "S\t1\tACGT\nP\ts1\t1+\t*")
    unnamed <- Biostrings::DNAStringSet("ACGT")
    expect_error(auditGFA(unnamed, case$gfa),
        class = "panpathAudit_argument_error")
    expect_error(auditGFA(list(case$fasta, 1), case$gfa),
        class = "panpathAudit_argument_error")
    expect_error(auditGFA(list(), case$gfa),
        class = "panpathAudit_argument_error")
    expect_error(auditGFA(character(), case$gfa),
        class = "panpathAudit_argument_error")
    injected <- Biostrings::DNAStringSet(c("s1\nACGT" = "ACGT"))
    expect_error(auditGFA(injected, case$gfa),
        "line breaks", class = "panpathAudit_argument_error")
    named <- Biostrings::DNAStringSet(c(s1 = "ACGT"))
    pattern <- "^panpathAudit-.*\\.fa$"
    before <- list.files(tempdir(), pattern)
    expect_error(auditGFA(named, case$gfa, threads = 0),
        class = "panpathAudit_argument_error")
    expect_identical(list.files(tempdir(), pattern), before)
})
