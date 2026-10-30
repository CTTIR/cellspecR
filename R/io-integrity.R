# Integrity helpers for canonical cellspec directories.

.cs_sha256_file <- function(path) {
  tools_ns <- asNamespace("tools")
  if (exists("sha256sum", envir = tools_ns, inherits = FALSE)) {
    return(unname(get("sha256sum", envir = tools_ns)(path)))
  }
  # nocov start -- compatibility with R versions without tools::sha256sum
  digest::digest(file = path, algo = "sha256")
  # nocov end
}

.cs_safe_relative_path <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    return(FALSE)
  }
  if (grepl("[\\\\:\r\n]", path)) return(FALSE)
  if (grepl("^(?:[A-Za-z]:[\\\\/]|[\\\\/]|//)", path, perl = TRUE)) {
    return(FALSE)
  }
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  !any(parts %in% c("", ".", ".."))
}

.cs_is_link <- function(path) {
  link <- Sys.readlink(path)
  !is.na(link) & nzchar(link)
}

# Do not follow links while hashing, reading control files or listing members.
.cs_regular_member <- function(dir, member) {
  parts <- strsplit(member, "/", fixed = TRUE)[[1L]]
  path <- dir
  for (part in parts) {
    path <- file.path(path, part)
    if (.cs_is_link(path)) return(FALSE)
  }
  file.exists(path) && !dir.exists(path)
}

.cs_directory_members <- function(dir, prefix = "") {
  entries <- list.files(file.path(dir, prefix), all.files = TRUE, no.. = TRUE)
  members <- if (nzchar(prefix)) paste(prefix, entries, sep = "/") else entries
  out <- character()
  for (member in members) {
    path <- file.path(dir, member)
    if (!.cs_is_link(path) && dir.exists(path)) {
      nested <- .cs_directory_members(dir, member)
      out <- c(out, if (length(nested)) nested else member)
    } else {
      out <- c(out, member)
    }
  }
  out
}

.cs_manifest_entries <- function(dir, call = rlang::caller_env()) {
  path <- file.path(dir, "MANIFEST.sha256")
  if (!.cs_regular_member(dir, "MANIFEST.sha256")) {
    .cs_abort(
      "MANIFEST.sha256 must be a regular file inside the cellspec directory.",
      class = "cellspec_error_integrity",
      call = call
    )
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0L) {
    .cs_abort(
      "MANIFEST.sha256 is empty.",
      class = "cellspec_error_integrity",
      call = call
    )
  }
  match <- regexec("^([0-9a-fA-F]{64})[ \t]+(.+)$", lines, perl = TRUE)
  pieces <- regmatches(lines, match)
  valid <- vapply(pieces, length, integer(1)) == 3L
  if (!all(valid)) {
    .cs_abort(
      c(
        "MANIFEST.sha256 contains an invalid entry.",
        "x" = "Each line must contain a 64-character SHA-256 digest and a relative path."
      ),
      class = "cellspec_error_integrity",
      call = call
    )
  }
  expected <- tolower(vapply(pieces, function(x) x[[2L]], character(1)))
  files <- vapply(pieces, function(x) x[[3L]], character(1))
  if (!all(vapply(files, .cs_safe_relative_path, logical(1)))) {
    .cs_abort(
      "MANIFEST.sha256 contains an unsafe relative path.",
      class = "cellspec_error_integrity",
      call = call
    )
  }
  if (anyDuplicated(files)) {
    .cs_abort(
      "MANIFEST.sha256 contains a duplicated file entry.",
      class = "cellspec_error_integrity",
      call = call
    )
  }
  data.frame(file = files, expected = expected, stringsAsFactors = FALSE)
}

.cs_integrity_report <- function(dir, call = rlang::caller_env()) {
  entries <- .cs_manifest_entries(dir, call = call)
  manifest <- file.path(dir, "MANIFEST.sha256")
  observed <- vapply(entries$file, function(file) {
    path <- file.path(dir, file)
    if (!.cs_regular_member(dir, file)) {
      return(NA_character_)
    }
    tolower(.cs_sha256_file(path))
  }, character(1))
  files <- entries$file
  ok <- !is.na(observed) & observed == entries$expected

  done_path <- file.path(dir, "DONE")
  done_observed <- if (.cs_regular_member(dir, "DONE")) {
    paste(trimws(readLines(done_path, n = 1L, warn = FALSE, encoding = "UTF-8")),
          collapse = "")
  } else {
    NA_character_
  }
  done_expected <- tolower(.cs_sha256_file(manifest))
  done_ok <- !is.na(done_observed) && identical(done_observed, done_expected)

  listed <- c(files, "MANIFEST.sha256", "DONE")
  actual <- .cs_directory_members(dir)
  extra <- setdiff(actual, listed)
  if (length(extra) > 0L) {
    entries <- rbind(
      entries,
      data.frame(file = extra, expected = rep(NA_character_, length(extra)),
                 stringsAsFactors = FALSE)
    )
    files <- c(files, extra)
    observed <- c(observed, rep(NA_character_, length(extra)))
    ok <- c(ok, rep(FALSE, length(extra)))
  }

  out <- data.frame(
    file = files,
    expected = entries$expected,
    observed = observed,
    ok = ok,
    stringsAsFactors = FALSE
  )
  rbind(
    out,
    data.frame(
      file = "DONE",
      expected = done_expected,
      observed = done_observed,
      ok = done_ok,
      stringsAsFactors = FALSE
    )
  )
}

#' Verify a canonical cellspec directory
#'
#' @description
#' Recomputes every digest in MANIFEST.sha256 and checks the DONE marker
#' against the manifest digest. The returned report has one row per declared
#' file plus DONE; it does not hide a failed digest behind an error.
#' Hidden files are included. Symbolic-link members are refused, so a verified
#' directory does not depend on files outside it. Checksums detect changes;
#' they do not authenticate the producer of a directory.
#'
#' @param dir A cellspec directory written by cs_write().
#' @return A data frame with character columns file, expected and observed,
#'   and logical column ok. ok is FALSE for a missing, modified or unexpected
#'   file, or for an invalid DONE marker.
#' @family canonical-format
#' @seealso cs_read_cellspec()
#' @export
#' @examples
#' path <- tempfile("cellspec-")
#' cs_write(cs_example(), path)
#' cs_verify(path)
cs_verify <- function(dir) {
  .cs_check_string(dir, arg = "dir")
  if (!dir.exists(dir)) {
    .cs_abort(
      "dir must be an existing directory.",
      class = "cellspec_error_format"
    )
  }
  .cs_integrity_report(dir)
}
