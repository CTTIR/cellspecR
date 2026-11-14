test_that("failed replacement preserves original files and names failed recovery", {
  exercise <- function(fail_calls) {
    parent <- withr::local_tempdir()
    target <- file.path(parent, "canonical")
    original <- cs_example()
    cs_write(original, target)
    hashes <- function(path) {
      files <- sort(list.files(path, all.files = TRUE, no.. = TRUE))
      setNames(vapply(file.path(path, files), cellspecR:::.cs_sha256_file,
                      character(1)), files)
    }
    before <- hashes(target)
    replacement <- original
    replacement$measurements <- replacement$measurements + 1

    # Inject only rename outcomes into the real commit helper; all serialization,
    # backup contents, cleanup and integrity verification use the filesystem.
    commit <- cellspecR:::.cs_commit_stage
    injected <- new.env(parent = environment(commit))
    calls <- 0L
    injected$file.rename <- function(from, to) {
      calls <<- calls + 1L
      if (calls %in% fail_calls) return(FALSE)
      base::file.rename(from, to)
    }
    environment(commit) <- injected
    local_mocked_bindings(.cs_commit_stage = commit, .package = "cellspecR")
    error <- tryCatch({
      cs_write(replacement, target, overwrite = TRUE)
      NULL
    }, error = identity)
    expect_s3_class(error, "cellspec_error_format")
    backups <- list.files(parent, pattern = "backup-", full.names = TRUE)
    if (identical(fail_calls, c(2L, 3L))) {
      expect_false(dir.exists(target))
      expect_length(backups, 1L)
      expect_match(conditionMessage(error), basename(backups), fixed = TRUE)
      expect_match(conditionMessage(error), "could not be restored automatically",
                   fixed = TRUE)
      expect_identical(hashes(backups), before)
      expect_true(all(cs_verify(backups)$ok))
    } else {
      expect_identical(hashes(target), before)
      expect_length(backups, 0L)
      expect_true(all(cs_verify(target)$ok))
    }
    expect_length(list.files(parent, pattern = "partial-"), 0L)
  }
  for (fail_calls in list(1L, 2L, c(2L, 3L))) exercise(fail_calls)
})
