# QuPath measurement-export adapter.

.cs_qupath_adapter_version <- "1.0.1"

.cs_qupath_header <- function(x) {
  value <- as.character(x)
  value <- sub("^\ufeff", "", value)
  value <- gsub("\u00c2\u00b5m", "um", value, fixed = TRUE)
  value <- gsub("\u00b5m", "um", value, fixed = TRUE)
  value <- gsub("\u03bcm", "um", value, fixed = TRUE)
  value <- gsub("\u00b5", "u", value, fixed = TRUE)
  value <- gsub("\u03bc", "u", value, fixed = TRUE)
  value <- gsub("^2", "2", value, fixed = TRUE)
  trimws(value)
}

.cs_qupath_find <- function(names, patterns) {
  normal <- tolower(.cs_qupath_header(names))
  for (pattern in patterns) {
    hit <- which(normal %in% tolower(pattern))
    if (length(hit) > 0L) return(names[[hit[[1L]]]])
  }
  NULL
}

.cs_qupath_coordinate <- function(names, axis, unit) {
  axis <- tolower(axis)
  unit <- tolower(unit)
  candidates <- if (unit == "um") {
    c(
      paste0("centroid ", toupper(substr(axis, 1L, 1L)), substr(axis, 2L, nchar(axis)), " um"),
      paste0("centroid_", axis, "_um"),
      paste0("centroid ", axis, " (um)"),
      paste0("centroid:", axis, ":um")
    )
  } else {
    c(
      paste0("centroid ", toupper(substr(axis, 1L, 1L)), substr(axis, 2L, nchar(axis)), " px"),
      paste0("centroid_", axis, "_px"),
      paste0("centroid ", axis, " (px)"),
      paste0("centroid:", axis, ":px")
    )
  }
  .cs_qupath_find(names, candidates)
}

.cs_qupath_statistic <- function(value) {
  value <- tolower(trimws(value))
  value <- sub("^q([0-9]+)$", "q\\1", value)
  aliases <- c(average = "mean", avg = "mean", stdev = "sd", std = "sd")
  if (value %in% names(aliases)) unname(aliases[[value]]) else value
}

.cs_qupath_compartment <- function(value) {
  value <- tolower(trimws(value))
  aliases <- c(
    cytoplasm = "cytoplasm", cytosol = "cytoplasm", membrane = "membrane",
    nucleus = "nucleus", cell = "cell", wholecell = "cell",
    whole = "cell"
  )
  if (value %in% names(aliases)) unname(aliases[[value]]) else NULL
}

.cs_qupath_measurement <- function(name) {
  original <- as.character(name)
  clean <- .cs_qupath_header(original)
  clean <- sub("\\s+\\([^)]*\\)$", "", clean)
  parts <- trimws(strsplit(clean, ":", fixed = TRUE)[[1L]])
  if (any(!nzchar(parts))) {
    return(NULL)
  }
  if (length(parts) < 2L) {
    return(NULL)
  }
  statistic <- .cs_qupath_statistic(parts[[length(parts)]])
  if (!statistic %in% .cs_vocab_values("intensity_statistic")) {
    return(NULL)
  }
  if (length(parts) == 2L) {
    compartment <- "cell"
    marker <- parts[[1L]]
  } else {
    compartment <- .cs_qupath_compartment(parts[[1L]])
    if (is.null(compartment)) {
      return(NULL)
    }
    marker <- paste(parts[2:(length(parts) - 1L)], collapse = ":")
  }
  if (is.na(marker) || !nzchar(marker) || grepl(":", marker, fixed = TRUE)) {
    return(NULL)
  }
  data.frame(
    source_name = original,
    kind = "intensity",
    marker = marker,
    compartment = compartment,
    statistic = statistic,
    unit = "a.u.",
    stringsAsFactors = FALSE
  )
}

.cs_qupath_shape <- function(name) {
  clean <- tolower(.cs_qupath_header(name))
  clean <- gsub("[^a-z0-9]+", " ", clean, perl = TRUE)
  clean <- trimws(clean)
  statistic <- if (grepl("^area( |$)", clean)) {
    "area"
  } else if (grepl("perimeter", clean, fixed = TRUE)) {
    "perimeter"
  } else if (grepl("circularity", clean, fixed = TRUE)) {
    "circularity"
  } else if (grepl("solidity", clean, fixed = TRUE)) {
    "solidity"
  } else {
    NULL
  }
  statistic
}

.cs_qupath_shape_metadata <- function(name) {
  clean <- tolower(.cs_qupath_header(name))
  parts <- trimws(strsplit(clean, ":", fixed = TRUE)[[1L]])
  compartment <- "cell"
  if (length(parts) == 2L) {
    compartment <- .cs_qupath_compartment(parts[[1L]])
    clean <- parts[[2L]]
  } else if (length(parts) != 1L) {
    return(NULL)
  }
  if (is.null(compartment)) return(NULL)
  unit <- if (grepl(" um2$", clean)) "um2" else if (grepl(" um$", clean)) "um" else
    if (grepl(" px2$", clean)) "px2" else if (grepl(" px$", clean)) "px" else "1"
  label <- sub(" (um2|um|px2|px)$", "", clean)
  shapes <- c(
    area = "area", perimeter = "perimeter", length = "length",
    circularity = "circularity", solidity = "solidity",
    `max diameter` = "max_diameter", `min diameter` = "min_diameter",
    `nucleus/cell area ratio` = "nucleus_cell_area_ratio"
  )
  if (!label %in% names(shapes)) return(NULL)
  statistic <- unname(shapes[[label]])
  if (statistic == "area" && !unit %in% c("um2", "px2")) return(NULL)
  if (statistic %in% c("perimeter", "length", "max_diameter", "min_diameter") &&
      !unit %in% c("um", "px")) return(NULL)
  if (statistic %in% c("circularity", "solidity", "nucleus_cell_area_ratio") &&
      unit != "1") return(NULL)
  data.frame(
    source_name = name, kind = "shape", marker = NA_character_,
    compartment = compartment, statistic = statistic, unit = unit,
    stringsAsFactors = FALSE
  )
}

.cs_qupath_map <- function(table_names, pixel_size = NULL, marker_map = NULL,
                           call = rlang::caller_env()) {
  id <- .cs_qupath_find(table_names, c(
    "cell id", "cell_id", "detection id", "object id", "id"
  ))
  if (is.null(id)) {
    .cs_table_abort("The QuPath export has no cell identifier column.", call = call)
  }
  x_um <- .cs_qupath_coordinate(table_names, "x", "um")
  y_um <- .cs_qupath_coordinate(table_names, "y", "um")
  x_px <- .cs_qupath_coordinate(table_names, "x", "px")
  y_px <- .cs_qupath_coordinate(table_names, "y", "px")
  unit <- if (!is.null(x_um) && !is.null(y_um)) "um" else if (!is.null(x_px) && !is.null(y_px)) "px" else NULL
  if (is.null(unit)) {
    .cs_abort(
      "The QuPath export must contain both x and y centroids in `um` or `px`.",
      class = "cellspec_error_units",
      call = call
    )
  }
  x <- if (unit == "um") x_um else x_px
  y <- if (unit == "um") y_um else y_px
  area <- .cs_qupath_find(table_names, c(
    "cell: area um2", "cell area um2", "area um2", "cell: area", "area"
  ))
  if (!is.null(area) && identical(.cs_qupath_shape(area), "area")) {
    area <- area
  }
  image <- .cs_qupath_find(table_names, c(
    "image", "image id", "image_id", "image name", "server"
  ))
  sample <- .cs_qupath_find(table_names, c("sample", "sample id", "sample_id"))
  metadata <- list()
  excluded <- unique(c(id, x, y, x_um, y_um, x_px, y_px, area, image, sample))
  candidates <- setdiff(table_names, excluded)
  for (name in candidates) {
    row <- .cs_qupath_measurement(name)
    if (is.null(row)) row <- .cs_qupath_shape_metadata(name)
    if (!is.null(row)) metadata[[length(metadata) + 1L]] <- row
  }
  metadata <- if (length(metadata) == 0L) {
    NULL
  } else {
    do.call(rbind, metadata)
  }
  if (!is.null(marker_map)) {
    if (!is.data.frame(marker_map) || !identical(names(marker_map), c("from", "to"))) {
      .cs_table_abort("{.arg marker_map} must be created with {.fn cs_marker_map}.", call = call)
    }
    if (!is.null(metadata)) {
      hit <- match(metadata$marker, marker_map$from)
      metadata$marker[!is.na(hit)] <- marker_map$to[hit[!is.na(hit)]]
    }
  }
  list(
    cell_id = id, x = x, y = y, image_id = image, sample_id = sample,
    area = area, coordinate_unit = unit, measurements = metadata,
    x_px = x_px, y_px = y_px
  )
}

.cs_qupath_detect <- function(path, n_max = 50L, call = rlang::caller_env()) {
  if (!file.exists(path) || dir.exists(path)) return(NULL)
  table <- tryCatch(.cs_table_read(path, n_max = n_max, call = call), error = function(e) NULL)
  if (is.null(table)) return(NULL)
  has_id <- !is.null(.cs_qupath_find(names(table), c("cell id", "cell_id", "detection id", "object id")))
  has_um <- !is.null(.cs_qupath_coordinate(names(table), "x", "um")) &&
    !is.null(.cs_qupath_coordinate(names(table), "y", "um"))
  has_px <- !is.null(.cs_qupath_coordinate(names(table), "x", "px")) &&
    !is.null(.cs_qupath_coordinate(names(table), "y", "px"))
  has_measurements <- any(vapply(names(table), function(name) !is.null(.cs_qupath_measurement(name)), logical(1)))
  if (!has_id || (!has_um && !has_px && !has_measurements)) return(NULL)
  score <- 0.05 + 0.25 * has_id + 0.35 * (has_um || has_px) + 0.25 * has_measurements
  data.frame(
    format = "qupath",
    score = min(score, 1),
    evidence = paste(
      c(
        if (has_id) "cell identifier" else NULL,
        if (has_um) "micrometre centroids" else if (has_px) "pixel centroids" else NULL,
        if (has_measurements) "colon-delimited measurements" else NULL
      ),
      collapse = ", "
    ),
    stringsAsFactors = FALSE
  )
}

.cs_qupath_read <- function(path, pixel_size = NULL, image_id = NULL,
                            sample_id = NULL, marker_map = NULL,
                            keep_other = TRUE, keep_paths = FALSE, quiet = FALSE,
                            call = rlang::caller_env()) {
  .cs_check_path(path, call = call)
  if (dir.exists(path)) {
    .cs_table_abort("The QuPath adapter expects one CSV or TSV measurement file.", call = call)
  }
  table <- .cs_table_read(path, call = call)
  map <- .cs_qupath_map(names(table), pixel_size = pixel_size, marker_map = marker_map, call = call)
  if (identical(map$coordinate_unit, "px") && is.null(pixel_size)) {
    .cs_abort(
      "Pixel centroids in a QuPath export require {.arg pixel_size} in micrometres per pixel.",
      class = "cellspec_error_units",
      call = call
    )
  }
  out <- cs_read(
    path,
    format = "table",
    pixel_size = pixel_size,
    image_id = image_id,
    sample_id = sample_id,
    column_map = structure(map, class = c("cs_column_map", "list")),
    keep_other = keep_other,
    keep_paths = keep_paths,
    quiet = quiet
  )
  out$provenance$reader$adapter <- "qupath"
  out$provenance$reader$adapter_version <- .cs_qupath_adapter_version
  out$provenance$parameters$header_grammar <- "QuPath colon-delimited measurement export"
  out <- .cs_add_history(out, step = "read", fun = "cs_read", details = list(
    format = "qupath", n_cells = nrow(out$cells)
  ))
  cs_assert_valid(out, level = "structure", call = call)
  out
}
