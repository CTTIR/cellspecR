# Bounded tiled QuPath adapter.

.cs_tiled_adapter_version <- "1.0.1"
.cs_tiled_prefix <- c(
  "sample", "cell_id", "centroid_x_px", "centroid_y_px",
  "centroid_x_um", "centroid_y_um"
)
.cs_tiled_table_pattern <- "\\.(csv|tsv|txt)(\\.gz)?$"

.cs_tiled_abort <- function(message, class = "cellspec_error_format",
                            call = rlang::caller_env()) {
  .cs_abort(message, class = class, call = call, .envir = parent.frame())
}

.cs_tiled_check_directory <- function(path, call = rlang::caller_env()) {
  .cs_check_path(path, call = call)
  if (!dir.exists(path)) {
    .cs_tiled_abort(
      c(
        "{.arg path} must be a directory of tiled tables.",
        "x" = "Got the file {.path {path}}."
      ),
      call = call
    )
  }
  invisible(path)
}

.cs_tiled_table_name <- function(path) {
  basename(path)
}

.cs_tiled_stem <- function(path) {
  name <- basename(path)
  name <- sub("\\.gz$", "", name, ignore.case = TRUE)
  sub("\\.(csv|tsv|txt)$", "", name, ignore.case = TRUE)
}

.cs_tiled_is_bounds_name <- function(name) {
  stem <- sub("\\.gz$", "", name, ignore.case = TRUE)
  stem <- sub("\\.(csv|tsv|txt)$", "", stem, ignore.case = TRUE)
  tolower(stem) %in% c(
    "bounds", "tile_bounds", "tile-bounds", "tile.bounds"
  )
}

.cs_tiled_list_files <- function(path, call = rlang::caller_env()) {
  entries <- list.files(
    path, full.names = TRUE, recursive = FALSE, include.dirs = TRUE,
    all.files = TRUE, no.. = TRUE
  )
  directories <- entries[dir.exists(entries)]
  if (length(directories) > 0L) {
    .cs_tiled_abort(
      c(
        "{.arg path} must contain tile tables directly, without nested directories.",
        "x" = "Nested directories include {.path {basename(directories)}}."
      ),
      call = call
    )
  }
  files <- entries[file.exists(entries) & !dir.exists(entries)]
  files <- files[grepl(.cs_tiled_table_pattern, basename(files), ignore.case = TRUE)]
  files <- files[!grepl("\\.done\\.tsv$", basename(files), ignore.case = TRUE)]
  files <- files[!grepl("\\.metadata\\.tsv$", basename(files), ignore.case = TRUE)]
  files <- files[!.cs_tiled_is_bounds_name(basename(files))]
  files <- files[order(basename(files), files)]
  if (length(files) == 0L) {
    .cs_tiled_abort(
      c(
        "No tile tables were found in {.path {path}}.",
        "i" = "Use CSV, TSV or TXT files directly inside the directory."
      ),
      call = call
    )
  }
  files
}

.cs_tiled_done_files <- function(path, tile_files, call = rlang::caller_env()) {
  entries <- list.files(
    path, full.names = TRUE, recursive = FALSE, include.dirs = FALSE,
    all.files = TRUE, no.. = TRUE
  )
  done <- entries[
    file.exists(entries) &
      grepl("\\.done\\.tsv$", basename(entries), ignore.case = TRUE)
  ]
  if (length(done) == 0L) {
    return(vector("list", length(tile_files)))
  }
  done <- done[order(basename(done), done)]
  parsed <- lapply(done, .cs_tiled_read_done, call = call)
  names(parsed) <- basename(done)
  tile_stems <- .cs_tiled_stem(tile_files)
  result <- vector("list", length(tile_files))
  names(result) <- tile_stems
  used <- logical(length(done))

  for (i in seq_along(tile_files)) {
    exact <- which(tolower(names(parsed)) == paste0(
      tolower(tile_stems[[i]]), ".done.tsv"
    ))
    if (length(exact) == 1L) {
      result[[i]] <- parsed[[exact]]
      used[[exact]] <- TRUE
    }
  }

  for (i in which(vapply(result, is.null, logical(1)))) {
    candidates <- which(!used & vapply(parsed, function(x) {
      id <- .cs_tiled_done_value(x, c("tile_id", "tile_tag"))
      !is.null(id) && identical(id, tile_stems[[i]])
    }, logical(1)))
    if (length(candidates) == 1L) {
      result[[i]] <- parsed[[candidates]]
      used[[candidates]] <- TRUE
    }
  }

  remaining <- which(!used)
  unmatched <- which(vapply(result, is.null, logical(1)))
  if (length(remaining) > 0L || length(unmatched) > 0L) {
    # A single file named `.done.tsv` is a useful convention for a one-tile
    # directory. It is deliberately rejected for a multi-tile directory,
    # because silently applying one marker to several files is unsafe.
    dot_done <- which(tolower(names(parsed)) == ".done.tsv")
    if (length(tile_files) == 1L && length(dot_done) == 1L &&
        length(unmatched) == 1L && length(remaining) == 1L) {
      result[[unmatched]] <- parsed[[dot_done]]
      used[[dot_done]] <- TRUE
      remaining <- which(!used)
      unmatched <- which(vapply(result, is.null, logical(1)))
    }
  }
  if (length(remaining) > 0L || length(unmatched) > 0L) {
    .cs_tiled_abort(
      c(
        "Done markers do not map one-to-one to tile tables.",
        "x" = "Unmatched tiles: {.val {tile_stems[unmatched]}}; unmatched markers: {.val {names(parsed)[remaining]}}."
      ),
      call = call
    )
  }
  result
}

.cs_tiled_read_done <- function(path, call = rlang::caller_env()) {
  connection <- if (grepl("\\.gz$", path, ignore.case = TRUE)) {
    gzfile(path, open = "rt", encoding = "UTF-8")
  } else {
    file(path, open = "rt", encoding = "UTF-8")
  }
  on.exit(close(connection), add = TRUE)
  lines <- readLines(connection, warn = FALSE)
  if (length(lines) == 0L) {
    .cs_tiled_abort(
      "A done marker cannot be empty.",
      call = call
    )
  }
  rows <- strsplit(sub("^\\ufeff", "", lines), "\\t", fixed = FALSE)
  if (identical(rows[[1L]], c("key", "value"))) {
    rows <- rows[-1L]
  }
  if (length(rows) == 0L) {
    .cs_tiled_abort("A done marker has no key/value rows.", call = call)
  }
  lengths <- lengths(rows)
  if (any(lengths != 2L)) {
    bad <- which(lengths != 2L)[[1L]]
    .cs_tiled_abort(
      c(
        "A done marker must contain two tab-separated fields per row.",
        "x" = "Row {bad} is malformed in {.path {basename(path)}}."
      ),
      call = call
    )
  }
  keys <- vapply(rows, `[[`, character(1), 1L)
  values <- vapply(rows, `[[`, character(1), 2L)
  keys[[1L]] <- sub("^\\ufeff", "", keys[[1L]])
  if (anyNA(keys) || any(!nzchar(keys)) || anyDuplicated(keys)) {
    .cs_tiled_abort(
      c(
        "A done marker must contain unique non-empty keys.",
        "x" = "Check {.path {basename(path)}}."
      ),
      call = call
    )
  }
  structure(as.list(stats::setNames(values, keys)), path = path,
            class = "cs_tiled_done")
}

.cs_tiled_done_value <- function(done, keys, required = FALSE,
                                 call = rlang::caller_env()) {
  if (is.null(done)) {
    if (required) {
      .cs_tiled_abort("A done marker is required here but was not supplied.", call = call)
    }
    return(NULL)
  }
  present <- keys[keys %in% names(done)]
  if (length(present) == 0L) {
    if (required) {
      .cs_tiled_abort(
        c(
          "A done marker lacks a required key.",
          "x" = "Add one of {.val {keys}}."
        ),
        call = call
      )
    }
    return(NULL)
  }
  value <- done[[present[[1L]]]]
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    .cs_tiled_abort(
      c(
        "A done marker has an empty value.",
        "x" = "Key {.field {present[[1L]]}} is invalid."
      ),
      call = call
    )
  }
  value
}

.cs_tiled_number <- function(value, key, integer = FALSE,
                             min = -Inf, call = rlang::caller_env()) {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) {
    .cs_tiled_abort(
      "Done metadata key {.field {key}} must have a value.", call = call
    )
  }
  parsed <- suppressWarnings(as.numeric(value))
  valid <- length(parsed) == 1L && is.finite(parsed) && parsed >= min
  if (integer) {
    valid <- valid && parsed == round(parsed)
  }
  if (!valid) {
    .cs_tiled_abort(
      c(
        "Done metadata key {.field {key}} is not valid numeric metadata.",
        "x" = "Got {.val {value}}."
      ),
      call = call
    )
  }
  if (integer) as.integer(parsed) else as.double(parsed)
}

.cs_tiled_validate_done <- function(done, file, table, verify = TRUE,
                                    call = rlang::caller_env()) {
  if (is.null(done)) {
    return(invisible(NULL))
  }
  required <- c("csv_sha256", "data_rows", "columns", "bytes")
  missing <- setdiff(required, names(done))
  if (length(missing) > 0L) {
    .cs_tiled_abort(
      c(
        "Done metadata is incomplete.",
        "x" = "Missing {.val {missing}} for {.path {basename(file)}}."
      ),
      call = call
    )
  }
  sha <- .cs_tiled_done_value(done, "csv_sha256", required = TRUE, call = call)
  if (!grepl("^[A-Fa-f0-9]{64}$", sha)) {
    .cs_tiled_abort(
      "Done metadata `csv_sha256` must be a 64-character hexadecimal digest.",
      call = call
    )
  }
  expected_rows <- .cs_tiled_number(
    done[["data_rows"]], "data_rows", integer = TRUE, min = 0, call = call
  )
  expected_columns <- .cs_tiled_number(
    done[["columns"]], "columns", integer = TRUE, min = 1, call = call
  )
  expected_bytes <- .cs_tiled_number(
    done[["bytes"]], "bytes", integer = TRUE, min = 0, call = call
  )
  if ("status" %in% names(done) && !identical(done[["status"]], "validated")) {
    .cs_tiled_abort(
      "Done metadata `status` must be `validated` when supplied.",
      call = call
    )
  }
  if (!isTRUE(verify)) {
    return(invisible(NULL))
  }
  info <- file.info(file)
  observed_bytes <- as.double(info$size[[1L]])
  observed_sha <- unname(.cs_sha256_file(file))[[1L]]
  observed_rows <- nrow(table)
  observed_columns <- ncol(table)
  if (!identical(expected_rows, as.integer(observed_rows)) ||
      !identical(expected_columns, as.integer(observed_columns)) ||
      !identical(expected_bytes, as.integer(observed_bytes)) ||
      !identical(tolower(sha), tolower(observed_sha))) {
    .cs_tiled_abort(
      c(
        "Done metadata does not match the tile table.",
        "x" = "The row count, column count, byte count or SHA-256 digest changed for {.path {basename(file)}}."
      ),
      call = call
    )
  }
  if ("header_sha256" %in% names(done)) {
    con <- file(file, open = "rb")
    on.exit(close(con), add = TRUE)
    header <- readBin(con, what = "raw", n = 1024L)
    newline <- match(as.raw(10L), header)
    if (is.na(newline)) {
      .cs_tiled_abort("The tile has no header line to verify.", call = call)
    }
    observed_header <- unname(digest::digest(header[seq_len(newline)], algo = "sha256",
                                              serialize = FALSE))
    if (!identical(tolower(done[["header_sha256"]]), tolower(observed_header))) {
      .cs_tiled_abort("Done metadata `header_sha256` does not match the tile.", call = call)
    }
  }
  invisible(NULL)
}

.cs_tiled_bounds_file <- function(path) {
  entries <- list.files(path, full.names = TRUE, recursive = FALSE,
                        include.dirs = FALSE, all.files = TRUE, no.. = TRUE)
  entries <- entries[file.exists(entries) & !dir.exists(entries)]
  entries <- entries[grepl(.cs_tiled_table_pattern, basename(entries), ignore.case = TRUE)]
  entries <- entries[vapply(basename(entries), .cs_tiled_is_bounds_name, logical(1))]
  entries[order(basename(entries), entries)]
}

.cs_tiled_done_bounds <- function(done, tile_id, pixel_size = NULL,
                                  call = rlang::caller_env()) {
  if (is.null(done)) {
    return(NULL)
  }
  um_keys <- c("xmin_um", "xmax_um", "ymin_um", "ymax_um")
  if (all(um_keys %in% names(done))) {
    return(data.frame(
      tile_id = tile_id,
      xmin = unname(vapply(done["xmin_um"], .cs_tiled_number, numeric(1), key = "xmin_um", call = call)),
      xmax = unname(vapply(done["xmax_um"], .cs_tiled_number, numeric(1), key = "xmax_um", call = call)),
      ymin = unname(vapply(done["ymin_um"], .cs_tiled_number, numeric(1), key = "ymin_um", call = call)),
      ymax = unname(vapply(done["ymax_um"], .cs_tiled_number, numeric(1), key = "ymax_um", call = call)),
      stringsAsFactors = FALSE
    ))
  }
  plain_keys <- c("xmin", "xmax", "ymin", "ymax")
  if (all(plain_keys %in% names(done))) {
    values <- unname(vapply(done[plain_keys], .cs_tiled_number, numeric(1),
                            key = plain_keys, call = call))
    return(data.frame(
      tile_id = tile_id, xmin = values[[1L]], xmax = values[[2L]],
      ymin = values[[3L]], ymax = values[[4L]], stringsAsFactors = FALSE
    ))
  }
  px_keys <- c("core_x0_px", "core_x1_px", "core_y0_px", "core_y1_px")
  if (!all(px_keys %in% names(done))) {
    return(NULL)
  }
  width <- .cs_tiled_done_value(done, c("pixel_width_um", "pixel_size"),
                                required = FALSE, call = call)
  height <- .cs_tiled_done_value(done, c("pixel_height_um", "pixel_size"),
                                 required = FALSE, call = call)
  width <- if (is.null(width)) pixel_size else .cs_tiled_number(
    width, "pixel_width_um", call = call
  )
  height <- if (is.null(height)) pixel_size else .cs_tiled_number(
    height, "pixel_height_um", call = call
  )
  if (is.null(width) || is.null(height) || width <= 0 || height <= 0) {
    .cs_tiled_abort(
      c(
        "Tile bounds in pixels require pixel calibration.",
        "x" = "Done metadata for {.val {tile_id}} has no positive pixel size."
      ),
      class = "cellspec_error_units",
      call = call
    )
  }
  values <- unname(vapply(done[px_keys], .cs_tiled_number, numeric(1),
                          key = px_keys, call = call))
  data.frame(
    tile_id = tile_id,
    xmin = values[[1L]] * width,
    xmax = values[[2L]] * width,
    ymin = values[[3L]] * height,
    ymax = values[[4L]] * height,
    stringsAsFactors = FALSE
  )
}

.cs_tiled_bounds <- function(path, tile_files, done, tile_bounds,
                             pixel_size = NULL, call = rlang::caller_env()) {
  if (!is.null(tile_bounds)) {
    .cs_check_data_frame(tile_bounds, arg = "tile_bounds", call = call)
    return(as.data.frame(tile_bounds, stringsAsFactors = FALSE))
  }
  bounds_files <- .cs_tiled_bounds_file(path)
  if (length(bounds_files) > 1L) {
    .cs_tiled_abort(
      "The tiled directory contains more than one bounds table.", call = call
    )
  }
  if (length(bounds_files) == 1L) {
    result <- .cs_table_read(bounds_files[[1L]], call = call)
    return(result)
  }
  rows <- lapply(seq_along(tile_files), function(i) {
    id <- .cs_tiled_id(tile_files[[i]], done[[i]], call = call)
    .cs_tiled_done_bounds(done[[i]], id, pixel_size = pixel_size, call = call)
  })
  if (any(vapply(rows, is.null, logical(1)))) {
    .cs_tiled_abort(
      c(
        "Tile bounds are required for tiled ownership.",
        "i" = "Supply {.arg tile_bounds} or include bounds in each `.done.tsv` marker."
      ),
      call = call
    )
  }
  do.call(rbind, rows)
}

.cs_tiled_id <- function(file, done = NULL, call = rlang::caller_env()) {
  from_done <- .cs_tiled_done_value(done, c("tile_id", "tile_tag"), call = call)
  if (!is.null(from_done)) {
    return(from_done)
  }
  stem <- .cs_tiled_stem(file)
  if (!nzchar(stem)) {
    .cs_tiled_abort("A tile table has an empty tile identifier.", call = call)
  }
  stem
}

.cs_tiled_pixel_size <- function(done, pixel_size = NULL,
                                 call = rlang::caller_env()) {
  values <- vapply(done, function(marker) {
    if (is.null(marker)) return(NA_real_)
    value <- .cs_tiled_done_value(
      marker, c("pixel_width_um", "pixel_size"), call = call
    )
    if (is.null(value)) NA_real_ else .cs_tiled_number(
      value, "pixel_width_um", call = call
    )
  }, numeric(1))
  values <- values[is.finite(values) & values > 0]
  if (!is.null(pixel_size)) {
    .cs_check_number(pixel_size, min = 0, arg = "pixel_size", call = call)
    if (pixel_size <= 0) {
      .cs_tiled_abort("{.arg pixel_size} must be positive.",
                      class = "cellspec_error_units", call = call)
    }
    values <- c(values, pixel_size)
  }
  if (length(values) == 0L) return(NULL)
  if (any(abs(values - values[[1L]]) > max(1e-12, abs(values[[1L]]) * 1e-9))) {
    .cs_tiled_abort(
      "Tiles use incompatible pixel calibrations.",
      class = "cellspec_error_units",
      call = call
    )
  }
  values[[1L]]
}

.cs_tiled_metadata <- function(headers) {
  headers <- as.character(headers)
  is_shape <- grepl(
    "^(Nucleus|Cytoplasm|Membrane|Cell): (Area|Length|Circularity|Solidity|Max diameter|Min diameter)( (?:\u00b5m|um)\\^2| (?:\u00b5m|um))?$",
    headers
  )
  shape <- headers[is_shape]
  shape_rows <- lapply(shape, function(source_name) {
    pieces <- strsplit(source_name, ": ", fixed = TRUE)[[1L]]
    compartment <- tolower(pieces[[1L]])
    label <- pieces[[2L]]
    unit <- if (grepl("\u00b5m|um", label)) {
      if (grepl("Area", label, fixed = TRUE)) "um2" else "um"
    } else {
      "1"
    }
    statistic <- if (grepl("Area", label, fixed = TRUE)) "area" else if (
      grepl("Length", label, fixed = TRUE)
    ) {
      "length"
    } else if (grepl("Circularity", label, fixed = TRUE)) {
      "circularity"
    } else if (grepl("Solidity", label, fixed = TRUE)) {
      "solidity"
    } else if (grepl("Max diameter", label, fixed = TRUE)) {
      "max_diameter"
    } else {
      "min_diameter"
    }
    data.frame(
      source_name = source_name, kind = "shape", marker = NA_character_,
      compartment = compartment, statistic = statistic, unit = unit,
      stringsAsFactors = FALSE
    )
  })
  intensity <- character()
  intensity_rows <- list()
  pattern <- "^(Nucleus|Cytoplasm|Membrane|Cell): (.+): (Mean|Median|Std\\.Dev\\.|Max|Min)$"
  for (source_name in headers[grepl(pattern, headers)]) {
    pieces <- trimws(strsplit(source_name, ":", fixed = TRUE)[[1L]])
    if (length(pieces) < 3L) next
    marker <- paste(pieces[2:(length(pieces) - 1L)], collapse = ":")
    statistic <- c(
      Mean = "mean", Median = "median", `Std.Dev.` = "sd",
      Max = "max", Min = "min"
    )[[pieces[[length(pieces)]]]]
    if (!is.null(statistic) && nzchar(marker) && !grepl(":", marker, fixed = TRUE)) {
      intensity <- c(intensity, source_name)
      intensity_rows[[length(intensity_rows) + 1L]] <- data.frame(
        source_name = source_name, kind = "intensity", marker = marker,
        compartment = tolower(pieces[[1L]]), statistic = statistic, unit = "a.u.",
        stringsAsFactors = FALSE
      )
    }
  }
  rows <- c(shape_rows, intensity_rows)
  if (length(rows) == 0L) return(NULL)
  do.call(rbind, rows)
}

.cs_tiled_fallback_read <- function(file, table, image_id, sample_id,
                                    pixel_size, marker_map, keep_other,
                                    keep_paths, quiet, call) {
  headers <- names(table)
  has_um <- all(c("centroid_x_um", "centroid_y_um") %in% headers)
  has_px <- all(c("centroid_x_px", "centroid_y_px") %in% headers)
  missing_prefix <- setdiff(c("sample", "cell_id"), headers)
  if (length(missing_prefix) > 0L || (!has_um && !has_px)) {
    required_prefix <- c(
      "cell_id", "centroid_x_um", "centroid_y_um",
      "centroid_x_px", "centroid_y_px"
    )
    .cs_tiled_abort(
      c(
        "A tiled table lacks the cellspec coordinate prefix.",
        "x" = "Required columns include {.val {required_prefix}}."
      ),
      call = call
    )
  }
  if (!has_um && is.null(pixel_size)) {
    .cs_tiled_abort(
      "Pixel-coordinate tiled tables require pixel calibration.",
      class = "cellspec_error_units",
      call = call
    )
  }
  x_name <- if (has_um) "centroid_x_um" else "centroid_x_px"
  y_name <- if (has_um) "centroid_y_um" else "centroid_y_px"
  unit <- if (has_um) "um" else "px"
  metadata <- .cs_tiled_metadata(headers)
  mapped <- cs_column_map(
    cell_id = "cell_id", x = x_name, y = y_name,
    sample_id = if ("sample" %in% headers) "sample" else NULL,
    coordinate_unit = unit, measurements = metadata
  )
  result <- cs_read(
    file, format = "table", pixel_size = pixel_size, image_id = image_id,
    sample_id = sample_id, column_map = mapped, keep_other = keep_other,
    keep_paths = keep_paths, quiet = quiet
  )
  if (has_um && all(c("centroid_x_px", "centroid_y_px") %in% headers) &&
      nrow(result$cells) > 0L) {
    result$cells$x_px <- .cs_table_numeric(
      table[["centroid_x_px"]], "centroid_x_px", call = call
    )
    result$cells$y_px <- .cs_table_numeric(
      table[["centroid_y_px"]], "centroid_y_px", call = call
    )
    duplicate_features <- intersect(
      c("other:centroid_x_px", "other:centroid_y_px"),
      colnames(result$measurements)
    )
    if (length(duplicate_features) > 0L) {
      result$measurements <- result$measurements[
        , setdiff(colnames(result$measurements), duplicate_features), drop = FALSE
      ]
      result$dictionary <- result$dictionary[
        !result$dictionary$feature_id %in% duplicate_features, , drop = FALSE
      ]
    }
  }
  cs_assert_valid(result, level = "structure", call = call)
  result
}

.cs_tiled_reader <- function() {
  candidates <- c(
    ".cs_qupath_read", ".cs_read_qupath", ".cs_qupath_read_file",
    ".cs_parse_qupath"
  )
  for (name in candidates) {
    value <- get0(name, envir = environment(), inherits = TRUE,
                  ifnotfound = NULL)
    if (is.function(value)) return(value)
  }
  NULL
}

.cs_tiled_read_one <- function(file, table, image_id, sample_id, pixel_size,
                               marker_map, keep_other, keep_paths, quiet,
                               call = rlang::caller_env()) {
  reader <- .cs_tiled_reader()
  if (is.null(reader)) {
    return(.cs_tiled_fallback_read(
      file, table, image_id, sample_id, pixel_size, marker_map, keep_other,
      keep_paths, quiet, call
    ))
  }
  args <- list(
    path = file, pixel_size = pixel_size, image_id = image_id,
    sample_id = sample_id, marker_map = marker_map, keep_other = keep_other,
    keep_paths = keep_paths, quiet = quiet, call = call
  )
  formal_names <- names(formals(reader))
  if (!"..." %in% formal_names) {
    args <- args[names(args) %in% formal_names]
  }
  if (!"path" %in% formal_names && "file" %in% formal_names) {
    args$file <- args$path
    args$path <- NULL
  }
  result <- do.call(reader, args)
  .cs_check_cellspec(result, arg = "tile", call = call)
  cs_assert_valid(result, level = "structure", call = call)
  result
}

.cs_tiled_relabel <- function(x, image_id, sample_id, tile_id,
                              call = rlang::caller_env()) {
  if (nrow(x$cells) > 0L) {
    x$cells$image_id <- rep(image_id, nrow(x$cells))
    if (!is.null(sample_id)) {
      x$cells$sample_id <- rep(sample_id, nrow(x$cells))
    }
    x$cells$tile_id <- rep(tile_id, nrow(x$cells))
  }
  if (nrow(x$images) > 0L) {
    x$images$image_id <- rep(image_id, nrow(x$images))
    if (!is.null(sample_id)) {
      x$images$sample_id <- rep(sample_id, nrow(x$images))
    }
    if ("source_image" %in% names(x$images)) x$images$source_image <- NULL
  }
  if (nrow(x$channels) > 0L) {
    x$channels$image_id <- rep(image_id, nrow(x$channels))
  }
  if (!is.null(x$adjacency) && nrow(x$adjacency) > 0L) {
    x$adjacency$image_id <- rep(image_id, nrow(x$adjacency))
  }
  cs_assert_valid(x, level = "structure", call = call)
  x
}

#' Detect a bounded tiled QuPath export.
#
#' This internal detector only accepts a directory whose tile tables are
#' direct children. A directory is a tiled export candidate when its tables
#' expose the six-column EVO prefix; generic tables remain low-confidence.
#' @noRd
.cs_tiled_detect <- function(path, n_max = 50L,
                             call = rlang::caller_env()) {
  .cs_tiled_check_directory(path, call = call)
  .cs_check_count(n_max, min = 0L, arg = "n_max", call = call)
  files <- .cs_tiled_list_files(path, call = call)
  headers <- lapply(files, function(file) {
    names(.cs_table_read(file, n_max = n_max, call = call))
  })
  prefix_count <- sum(vapply(headers, function(x) {
    all(.cs_tiled_prefix %in% x)
  }, logical(1)))
  score <- if (prefix_count == length(files)) 0.99 else if (prefix_count > 0L) 0.75 else 0
  evidence <- paste0(
    prefix_count, " of ", length(files), " tile table",
    if (length(files) == 1L) "" else "s", " have the six-column QuPath tiled prefix"
  )
  data.frame(
    format = "qupath_tiled",
    score = score,
    evidence = evidence,
    stringsAsFactors = FALSE
  )
}

.cs_tiled_read <- function(path, tile_bounds = NULL, pixel_size = NULL,
                           image_id = NULL, sample_id = NULL,
                           marker_map = NULL, keep_other = TRUE,
                           keep_paths = FALSE, verify_done = TRUE,
                           quiet = FALSE, call = rlang::caller_env()) {
  .cs_tiled_check_directory(path, call = call)
  .cs_check_flag(keep_other, arg = "keep_other", call = call)
  .cs_check_flag(keep_paths, arg = "keep_paths", call = call)
  .cs_check_flag(verify_done, arg = "verify_done", call = call)
  .cs_check_flag(quiet, arg = "quiet", call = call)
  .cs_check_string(image_id, allow_null = TRUE, arg = "image_id", call = call)
  .cs_check_string(sample_id, allow_null = TRUE, arg = "sample_id", call = call)
  if (!is.null(pixel_size)) {
    .cs_check_number(pixel_size, min = 0, arg = "pixel_size", call = call)
    if (pixel_size <= 0) {
      .cs_tiled_abort("{.arg pixel_size} must be positive.",
                      class = "cellspec_error_units", call = call)
    }
  }
  if (!is.null(marker_map)) {
    .cs_check_data_frame(marker_map, arg = "marker_map", call = call)
  }
  files <- .cs_tiled_list_files(path, call = call)
  done <- .cs_tiled_done_files(path, files, call = call)
  tile_ids <- vapply(seq_along(files), function(i) {
    .cs_tiled_id(files[[i]], done[[i]], call = call)
  }, character(1))
  if (anyDuplicated(tile_ids)) {
    .cs_tiled_abort(
      c(
        "Tile identifiers must be unique.",
        "x" = "Repeated {.val {unique(tile_ids[duplicated(tile_ids)])}}."
      ),
      class = "cellspec_error_collision",
      call = call
    )
  }
  tables <- lapply(files, function(file) .cs_table_read(file, call = call))
  for (i in seq_along(files)) {
    .cs_tiled_validate_done(done[[i]], files[[i]], tables[[i]],
                            verify = verify_done, call = call)
  }
  effective_pixel_size <- .cs_tiled_pixel_size(
    done, pixel_size = pixel_size, call = call
  )
  if (is.null(image_id)) {
    image_values <- vapply(done, function(marker) {
      value <- .cs_tiled_done_value(marker, "image_id", call = call)
      if (is.null(value)) NA_character_ else value
    }, character(1))
    image_values <- unique(image_values[!is.na(image_values)])
    if (length(image_values) == 1L) {
      image_id <- image_values[[1L]]
    } else {
      image_id <- basename(normalizePath(path, mustWork = TRUE))
    }
  }
  if (is.null(sample_id)) {
    sample_values <- vapply(done, function(marker) {
      value <- .cs_tiled_done_value(marker, "sample_id", call = call)
      if (is.null(value)) NA_character_ else value
    }, character(1))
    sample_values <- unique(sample_values[!is.na(sample_values)])
    if (length(sample_values) == 1L) sample_id <- sample_values[[1L]]
  }
  bounds <- .cs_tiled_bounds(
    path, files, done, tile_bounds, pixel_size = effective_pixel_size, call = call
  )
  if (!"tile_id" %in% names(bounds)) {
    .cs_tiled_abort("{.arg tile_bounds} must contain a `tile_id` column.", call = call)
  }
  bounds$tile_id <- as.character(bounds$tile_id)
  if (anyNA(bounds$tile_id) || any(!nzchar(bounds$tile_id))) {
    .cs_tiled_abort("Tile bounds contain an empty tile identifier.", call = call)
  }
  if (!setequal(bounds$tile_id, tile_ids)) {
    .cs_tiled_abort(
      c(
        "Tile bounds must name every tile exactly once.",
        "x" = "Table identifiers are {.val {tile_ids}}; bounds identifiers are {.val {bounds$tile_id}}."
      ),
      class = "cellspec_error_collision",
      call = call
    )
  }
  tiles <- lapply(seq_along(files), function(i) {
    tile <- .cs_tiled_read_one(
      files[[i]], tables[[i]], image_id = image_id, sample_id = sample_id,
      pixel_size = effective_pixel_size, marker_map = marker_map,
      keep_other = keep_other, keep_paths = keep_paths, quiet = quiet,
      call = call
    )
    .cs_tiled_relabel(tile, image_id, sample_id, tile_ids[[i]], call = call)
  })
  names(tiles) <- tile_ids
  result <- cs_merge_tiles(tiles, bounds, ownership = "centroid")
  result$provenance$reader$adapter <- "qupath_tiled"
  result$provenance$reader$adapter_version <- .cs_tiled_adapter_version
  result$provenance$parameters$tiled <- list(
    directory = basename(normalizePath(path, mustWork = TRUE)),
    verify_done = verify_done,
    tile_ids = tile_ids,
    pixel_size = effective_pixel_size
  )
  cs_assert_valid(result, level = "structure", call = call)
  result
}
