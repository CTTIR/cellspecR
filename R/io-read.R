# Canonical cellspec reader.

.cs_read_json <- function(path, call = rlang::caller_env()) {
  result <- tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) e
  )
  if (inherits(result, "error") || !is.list(result)) {
    message <- if (inherits(result, "error")) {
      conditionMessage(result)
    } else {
      "JSON root is not an object."
    }
    .cs_abort(
      c(
        "Could not read {.path {basename(path)}} as JSON.",
        "x" = message
      ),
      class = "cellspec_error_format",
      call = call
    )
  }
  result
}

.cs_json_columns <- function(payload, component, call = rlang::caller_env()) {
  if (!is.list(payload) || is.null(payload$columns) ||
      !is.list(payload$columns)) {
    .cs_abort(
      "{.field {component}} has no valid column description.",
      class = "cellspec_error_format",
      call = call
    )
  }
  desc <- payload$columns
  if (length(desc) == 0L) {
    return(data.frame(name = character(), type = character(),
                      stringsAsFactors = FALSE))
  }
  ok <- vapply(desc, function(x) {
    is.list(x) && is.character(x$name) && length(x$name) == 1L &&
      nzchar(x$name) && is.character(x$type) && length(x$type) == 1L
  }, logical(1))
  if (!all(ok)) {
    .cs_abort(
      "{.field {component}} contains an invalid column description.",
      class = "cellspec_error_format",
      call = call
    )
  }
  out <- data.frame(
    name = vapply(desc, function(x) x$name, character(1)),
    type = vapply(desc, function(x) x$type, character(1)),
    stringsAsFactors = FALSE
  )
  if (anyDuplicated(out$name) || !all(out$type %in% c(
    "character", "double", "integer", "logical"
  ))) {
    .cs_abort(
      "{.field {component}} contains duplicate names or unsupported types.",
      class = "cellspec_error_format",
      call = call
    )
  }
  out
}

.cs_json_value <- function(value, type) {
  if (is.null(value) || length(value) == 0L) {
    return(switch(type,
      character = NA_character_,
      double = NA_real_,
      integer = NA_integer_,
      logical = NA
    ))
  }
  switch(type,
    character = as.character(value[[1L]]),
    double = as.double(value[[1L]]),
    integer = as.integer(value[[1L]]),
    logical = as.logical(value[[1L]])
  )
}

.cs_json_table <- function(payload, component, call = rlang::caller_env()) {
  cols <- .cs_json_columns(payload, component, call = call)
  rows <- payload$rows
  if (is.null(rows)) {
    rows <- list()
  }
  if (!is.list(rows)) {
    .cs_abort(
      "{.field {component}} has invalid rows.",
      class = "cellspec_error_format",
      call = call
    )
  }
  values <- lapply(seq_len(nrow(cols)), function(i) {
    nm <- cols$name[[i]]
    type <- cols$type[[i]]
    vapply(rows, function(row) {
      if (!is.list(row)) {
        .cs_abort(
          "{.field {component}} contains a row that is not a JSON object.",
          class = "cellspec_error_format",
          call = call
        )
      }
      .cs_json_value(row[[nm]], type)
    }, FUN.VALUE = switch(type,
      character = character(1),
      double = double(1),
      integer = integer(1),
      logical = logical(1)
    ))
  })
  names(values) <- cols$name
  out <- as.data.frame(values, stringsAsFactors = FALSE, optional = TRUE)
  attr(out, "row.names") <- .set_row_names(length(rows))
  class(out) <- "data.frame"
  out
}

.cs_io_descriptors <- function(payload, component, call = rlang::caller_env()) {
  cols <- .cs_json_columns(payload, component, call = call)
  stats::setNames(cols$type, cols$name)
}

.cs_coerce_io_table <- function(df, payload, component,
                                call = rlang::caller_env()) {
  cols <- .cs_io_descriptors(payload, component, call = call)
  if (!identical(names(df), names(cols))) {
    .cs_abort(
      c(
        "The columns of {.field {component}} do not match cellspec.json.",
        "x" = "Expected {.val {names(cols)}}; found {.val {names(df)}}."
      ),
      class = "cellspec_error_format",
      call = call
    )
  }
  for (nm in names(cols)) {
    type <- cols[[nm]]
    df[[nm]] <- switch(type,
      character = as.character(df[[nm]]),
      double = as.double(df[[nm]]),
      integer = as.integer(df[[nm]]),
      logical = as.logical(df[[nm]])
    )
  }
  attr(df, "row.names") <- .set_row_names(nrow(df))
  class(df) <- "data.frame"
  df
}

.cs_read_table <- function(path, format, payload, component,
                           call = rlang::caller_env()) {
  if (!file.exists(path) || dir.exists(path)) {
    .cs_abort(
      "The declared {.field {component}} file {.path {basename(path)}} is missing.",
      class = "cellspec_error_integrity",
      call = call
    )
  }
  df <- if (format == "parquet") {
    result <- tryCatch(nanoparquet::read_parquet(path), error = function(e) e)
    if (inherits(result, "error")) {
      .cs_abort(
        c(
          "Could not read {.path {basename(path)}} as Parquet.",
          "x" = conditionMessage(result)
        ),
        class = "cellspec_error_format",
        call = call
      )
    }
    result
  } else {
    types <- .cs_io_descriptors(payload, component, call = call)
    gzip <- Sys.which("gzip")
    result <- tryCatch({
      if (.Platform$OS.type != "windows" && nzchar(gzip)) {
        data.table::fread(
          cmd = paste(shQuote(gzip), "-dc", shQuote(path)),
          sep = "\t",
          na.strings = "NA",
          data.table = FALSE,
          colClasses = "character",
          encoding = "UTF-8",
          showProgress = FALSE
        )
      } else {
        utils::read.delim(
          gzfile(path, open = "rt", encoding = "UTF-8"),
          sep = "\t",
          na.strings = "NA",
          quote = "\"",
          comment.char = "",
          colClasses = "character",
          check.names = FALSE,
          stringsAsFactors = FALSE
        )
      }
    }, error = function(e) e)
    if (inherits(result, "error")) {
      .cs_abort(
        c(
          "Could not read {.path {basename(path)}} as tab-separated text.",
          "x" = conditionMessage(result)
        ),
        class = "cellspec_error_format",
        call = call
      )
    }
    result
  }
  .cs_coerce_io_table(as.data.frame(df, stringsAsFactors = FALSE),
                      payload, component, call = call)
}

.cs_version_parts <- function(version) {
  if (!is.character(version) || length(version) != 1L ||
      is.na(version) || !grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", version)) {
    return(NULL)
  }
  as.integer(strsplit(version, ".", fixed = TRUE)[[1L]])
}

#' Read a canonical cellspec directory
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads the sidecar and cell table written by cs_write(), verifies the
#' manifest and DONE marker by default, and returns a validated object.
#' DONE is required even when verification is explicitly disabled.
#'
#' @param dir A canonical cellspec directory.
#' @param verify Whether to verify all manifest digests before reading data.
#' @return A validated cellspec object.
#' @family canonical-format
#' @seealso cs_write(), cs_verify()
#' @export
#' @examples
#' path <- tempfile("cellspec-")
#' cs_write(cs_example(), path)
#' y <- cs_read_cellspec(path)
#' identical(cs_cells(y), cs_cells(cs_example()))
cs_read_cellspec <- function(dir, verify = TRUE) {
  .cs_check_string(dir, arg = "dir")
  .cs_check_flag(verify, arg = "verify")
  if (!dir.exists(dir)) {
    .cs_abort(
      "dir must be an existing cellspec directory.",
      class = "cellspec_error_format"
    )
  }
  sidecar_path <- file.path(dir, "cellspec.json")
  if (!file.exists(sidecar_path)) {
    .cs_abort(
      "cellspec.json is missing from the cellspec directory.",
      class = "cellspec_error_format"
    )
  }
  if (!file.exists(file.path(dir, "DONE"))) {
    .cs_abort(
      "The cellspec directory has no DONE marker.",
      class = "cellspec_error_integrity"
    )
  }
  if (isTRUE(verify)) {
    report <- cs_verify(dir)
    if (any(!report$ok)) {
      bad <- report$file[!report$ok]
      .cs_abort(
        c(
          "Integrity verification failed for {.path {dir}}.",
          "x" = "Mismatched or unexpected file{?s}: {.val {bad}}."
        ),
        class = "cellspec_error_integrity",
        report = report
      )
    }
  }

  doc <- .cs_read_json(sidecar_path)
  parts <- .cs_version_parts(doc$spec_version)
  if (is.null(parts) || parts[[1L]] != 1L) {
    .cs_abort(
      "The cellspec sidecar has an unsupported specification version {.val {doc$spec_version}}.",
      class = "cellspec_error_version"
    )
  }
  current <- .cs_version_parts(cs_spec_version())
  if (parts[[2L]] > current[[2L]]) {
    .cs_abort(
      "The cellspec sidecar uses newer minor specification version {.val {doc$spec_version}}.",
      class = "cellspec_error_version"
    )
  }
  if (!is.list(doc$files) ||
      (!identical(doc$files$cells, "cells.parquet") &&
       !identical(doc$files$cells, "cells.tsv.gz"))) {
    .cs_abort(
      "The cellspec sidecar has an unknown cell-table format.",
      class = "cellspec_error_format"
    )
  }
  cell_path <- file.path(dir, doc$files$cells)
  dictionary <- .cs_json_table(doc$dictionary, "dictionary")
  images <- .cs_json_table(doc$images, "images")
  channels <- .cs_json_table(doc$channels, "channels")
  if (nrow(dictionary) == 0L) {
    feature_ids <- character()
  } else {
    feature_ids <- dictionary$feature_id
  }
  cell_payload <- list(
    columns = c(
      doc$cells$columns,
      lapply(feature_ids, function(feature_id) {
        list(name = feature_id, type = "double")
      })
    )
  )
  cells_table <- .cs_read_table(
    cell_path,
    if (identical(doc$files$cells, "cells.parquet")) "parquet" else "tsv.gz",
    cell_payload,
    "cells"
  )
  if (!is.list(doc$cells) || nrow(cells_table) != doc$cells$n_rows) {
    .cs_abort(
      "The cell-table row count differs from cellspec.json.",
      class = "cellspec_error_format"
    )
  }

  cell_columns <- .cs_io_descriptors(doc$cells, "cells")
  expected_names <- c(names(cell_columns), feature_ids)
  if (!identical(names(cells_table), expected_names)) {
    .cs_abort(
      c(
        "The columns of the cell table do not match cellspec.json.",
        "x" = "Expected {.val {expected_names}}; found {.val {names(cells_table)}}."
      ),
      class = "cellspec_error_format"
    )
  }
  cells <- cells_table[names(cell_columns)]
  if (length(feature_ids) == 0L) {
    measurements <- matrix(numeric(0), nrow = nrow(cells), ncol = 0L)
    dimnames(measurements) <- list(NULL, NULL)
  } else {
    measurements <- as.matrix(cells_table[feature_ids])
    storage.mode(measurements) <- "double"
    colnames(measurements) <- feature_ids
  }

  adjacency <- NULL
  adj_file <- doc$files$adjacency
  if (!is.null(adj_file)) {
    if (!identical(adj_file, "adjacency.parquet") &&
        !identical(adj_file, "adjacency.tsv.gz")) {
      .cs_abort(
        "The cellspec sidecar has an unknown adjacency-table format.",
        class = "cellspec_error_format"
      )
    }
    if (is.null(doc$adjacency) || !is.list(doc$adjacency)) {
      .cs_abort(
        "The adjacency table description is missing from cellspec.json.",
        class = "cellspec_error_format"
      )
    }
    adjacency <- .cs_read_table(
      file.path(dir, adj_file),
      if (identical(adj_file, "adjacency.parquet")) "parquet" else "tsv.gz",
      doc$adjacency,
      "adjacency"
    )
    if (nrow(adjacency) != doc$adjacency$n_rows) {
      .cs_abort(
        "The adjacency-table row count differs from cellspec.json.",
        class = "cellspec_error_format"
      )
    }
  }

  cs_new(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    provenance = doc$provenance,
    adjacency = adjacency
  )
}
