# Canonical cellspec writer.

.cs_io_column_type <- function(x, component, name, call = rlang::caller_env()) {
  if (is.character(x)) {
    return("character")
  }
  if (is.double(x)) {
    return("double")
  }
  if (is.integer(x)) {
    return("integer")
  }
  if (is.logical(x)) {
    return("logical")
  }
  .cs_abort(
    c(
      "Column {.field {name}} of {.field {component}} has an unsupported type.",
      "x" = "Use character, double, integer or logical columns."
    ),
    class = "cellspec_error_format",
    call = call
  )
}

.cs_io_columns <- function(df, component, call = rlang::caller_env()) {
  if (anyDuplicated(names(df))) {
    .cs_abort(
      "{.field {component}} has duplicated column names.",
      class = "cellspec_error_format",
      call = call
    )
  }
  types <- vapply(seq_along(df), function(i) {
    .cs_io_column_type(df[[i]], component, names(df)[[i]], call = call)
  }, character(1))
  lapply(seq_along(df), function(i) {
    list(name = names(df)[[i]], type = types[[i]])
  })
}

.cs_io_rows <- function(df) {
  if (nrow(df) == 0L) {
    return(list())
  }
  lapply(seq_len(nrow(df)), function(i) {
    as.list(df[i, , drop = FALSE])
  })
}

.cs_io_table <- function(df, component, include_rows = TRUE,
                         call = rlang::caller_env()) {
  out <- list(columns = .cs_io_columns(df, component, call = call))
  if (include_rows) {
    out$rows <- .cs_io_rows(df)
  }
  out
}

.cs_write_json <- function(x, path, call = rlang::caller_env()) {
  text <- tryCatch(
    jsonlite::toJSON(
      x,
      auto_unbox = TRUE,
      null = "null",
      na = "null",
      digits = NA,
      pretty = TRUE
    ),
    error = function(e) e
  )
  if (inherits(text, "error")) {
    .cs_abort(
      c(
        "Could not encode {.path {basename(path)}} as JSON.",
        "x" = conditionMessage(text)
      ),
      class = "cellspec_error_format",
      call = call
    )
  }
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(as.character(text), "\n"))), con)
  invisible(path)
}

.cs_format_tsv_double <- function(x) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  out[ok] <- format(x[ok], digits = 17, scientific = TRUE, trim = TRUE)
  out
}

.cs_write_tsv <- function(df, path, call = rlang::caller_env()) {
  out <- df
  doubles <- vapply(out, is.double, logical(1))
  out[doubles] <- lapply(out[doubles], .cs_format_tsv_double)
  tryCatch(
    data.table::fwrite(
      out,
      file = path,
      sep = "\t",
      na = "NA",
      quote = "auto",
      compress = "gzip",
      bom = FALSE
    ),
    error = function(e) {
      .cs_abort(
        c(
          "Could not write {.path {basename(path)}}.",
          "x" = conditionMessage(e)
        ),
        class = "cellspec_error_format",
        call = call
      )
    }
  )
  invisible(path)
}

.cs_write_table <- function(df, path, format, call = rlang::caller_env()) {
  if (format == "parquet") {
    result <- tryCatch(
      nanoparquet::write_parquet(df, path, compression = "gzip"),
      error = function(e) e
    )
    if (inherits(result, "error")) {
      .cs_abort(
        c(
          "Could not write {.path {basename(path)}} as Parquet.",
          "x" = conditionMessage(result)
        ),
        class = "cellspec_error_format",
        call = call
      )
    }
  } else {
    .cs_write_tsv(df, path, call = call)
  }
  invisible(path)
}

.cs_stage_path <- function(target, call = rlang::caller_env()) {
  parent <- dirname(target)
  if (!dir.exists(parent) && !dir.create(parent, recursive = TRUE, showWarnings = FALSE)) {
    .cs_abort(
      "Could not create the parent directory of {.path {target}}.",
      class = "cellspec_error_format",
      call = call
    )
  }
  paste0(
    target,
    ".partial-",
    Sys.getpid(),
    "-",
    paste(sample(c(letters, 0:9), 12L, replace = TRUE), collapse = "")
  )
}

.cs_commit_stage <- function(stage, target, overwrite, call = rlang::caller_env()) {
  backup <- NULL
  if (file.exists(target)) {
    backup <- paste0(
      target, ".backup-",
      Sys.getpid(), "-",
      paste(sample(c(letters, 0:9), 12L, replace = TRUE), collapse = "")
    )
    if (!file.rename(target, backup)) {
      .cs_abort(
        "Could not stage the existing destination {.path {target}} for replacement.",
        class = "cellspec_error_format",
        call = call
      )
    }
  }
  moved <- file.rename(stage, target)
  if (!moved) {
    if (!is.null(backup)) {
      file.rename(backup, target)
    }
    .cs_abort(
      "Could not move the completed cellspec directory into {.path {target}}.",
      class = "cellspec_error_format",
      call = call
    )
  }
  if (!is.null(backup)) {
    unlink(backup, recursive = TRUE, force = TRUE)
  }
  invisible(target)
}

#' Write a cellspec directory
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Writes a canonical cellspec directory in a neighbouring staging directory,
#' then renames it into place after the data, sidecar, manifest and DONE
#' marker are complete. Parquet is the default because it preserves doubles
#' exactly; the tsv.gz option is available for interoperable text output.
#'
#' @param x A valid cellspec object.
#' @param dir Destination directory. Its parent is created when needed.
#' @param format Storage format: parquet or tsv.gz.
#' @param overwrite Whether an existing destination may be replaced.
#' @return x, invisibly.
#' @family canonical-format
#' @seealso cs_read_cellspec(), cs_verify()
#' @export
#' @examples
#' path <- tempfile("cellspec-")
#' cs_write(cs_example(), path)
cs_write <- function(x, dir, format = c("parquet", "tsv.gz"),
                     overwrite = FALSE) {
  .cs_check_cellspec(x)
  .cs_check_string(dir, arg = "dir")
  format <- rlang::arg_match(format)
  .cs_check_flag(overwrite, arg = "overwrite")
  cs_assert_valid(x, level = "structure")

  target <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  if (file.exists(target) && !overwrite) {
    .cs_abort(
      c(
        "Destination {.path {target}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it."
      ),
      class = "cellspec_error_format"
    )
  }
  if (file.exists(target) && !dir.exists(target)) {
    .cs_abort(
      "{.arg dir} exists and is not a directory.",
      class = "cellspec_error_format"
    )
  }

  stage <- .cs_stage_path(target)
  if (!dir.create(stage, recursive = FALSE, showWarnings = FALSE)) {
    .cs_abort(
      "Could not create a staging directory beside {.path {target}}.",
      class = "cellspec_error_format"
    )
  }
  complete <- FALSE
  on.exit({
    if (!complete && dir.exists(stage)) {
      unlink(stage, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)

  cell_file <- if (format == "parquet") "cells.parquet" else "cells.tsv.gz"
  if (is.null(x$adjacency)) {
    adj_file <- NULL
  } else if (format == "parquet") {
    adj_file <- "adjacency.parquet"
  } else {
    adj_file <- "adjacency.tsv.gz"
  }
  measurement_df <- as.data.frame(x$measurements, optional = TRUE,
                                  check.names = FALSE)
  if (ncol(measurement_df) > 0L) {
    names(measurement_df) <- colnames(x$measurements)
  }
  if (length(intersect(names(x$cells), names(measurement_df))) > 0L) {
    .cs_abort(
      "Cell and measurement column names must be unique in the canonical table.",
      class = "cellspec_error_format"
    )
  }
  cell_table <- cbind(x$cells, measurement_df)
  .cs_write_table(cell_table, file.path(stage, cell_file), format)
  if (!is.null(x$adjacency)) {
    .cs_write_table(x$adjacency, file.path(stage, adj_file), format)
  }

  sidecar <- list(
    format = "cellspec",
    spec_version = x$spec_version,
    files = list(cells = cell_file, adjacency = adj_file),
    cells = list(
      n_rows = as.integer(nrow(x$cells)),
      columns = .cs_io_columns(x$cells, "cells")
    ),
    dictionary = .cs_io_table(x$dictionary, "dictionary"),
    images = .cs_io_table(x$images, "images"),
    channels = .cs_io_table(x$channels, "channels"),
    provenance = x$provenance,
    adjacency = if (is.null(x$adjacency)) NULL else list(
      n_rows = as.integer(nrow(x$adjacency)),
      columns = .cs_io_columns(x$adjacency, "adjacency")
    )
  )
  .cs_write_json(sidecar, file.path(stage, "cellspec.json"))

  manifest_files <- c(cell_file, "cellspec.json", adj_file)
  manifest_files <- manifest_files[!is.na(manifest_files)]
  manifest_files <- sort(manifest_files, method = "radix")
  hashes <- vapply(manifest_files, function(file) {
    .cs_sha256_file(file.path(stage, file))
  }, character(1))
  manifest_text <- paste(paste(hashes, manifest_files, sep = "  "), collapse = "\n")
  manifest_path <- file.path(stage, "MANIFEST.sha256")
  con <- file(manifest_path, open = "wb")
  writeBin(charToRaw(enc2utf8(paste0(manifest_text, "\n"))), con)
  close(con)

  hook <- getOption("cellspecR.test_write_hook", NULL)
  if (is.function(hook)) {
    hook(stage)
  }

  done_text <- paste0(.cs_sha256_file(manifest_path), "\n")
  con <- file(file.path(stage, "DONE"), open = "wb")
  writeBin(charToRaw(done_text), con)
  close(con)

  .cs_commit_stage(stage, target, overwrite = overwrite)
  complete <- TRUE
  invisible(x)
}
