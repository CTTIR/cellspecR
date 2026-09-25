# MCMICRO/MCQuant, segmantR and inForm table adapters.

.cs_other_abort <- function(message, class = "cellspec_error_format",
                            call = rlang::caller_env()) {
  .cs_abort(message, class = class, call = call, .envir = parent.frame())
}

.cs_other_data <- function(path, call = rlang::caller_env()) {
  if (grepl("\\.rds$", path, ignore.case = TRUE)) {
    value <- tryCatch(readRDS(path), error = function(e) e)
    if (inherits(value, "error")) {
      .cs_other_abort(
        c("Could not read {.path {basename(path)}} as an RDS table.",
          "x" = conditionMessage(value)), call = call
      )
    }
    if (!is.data.frame(value)) {
      .cs_other_abort("The RDS reader requires a data frame.", call = call)
    }
    return(as.data.frame(value, stringsAsFactors = FALSE, optional = TRUE))
  }
  .cs_table_read(path, call = call)
}

.cs_other_find <- function(names, values) {
  clean <- tolower(trimws(gsub("\\s+", " ", names)))
  for (value in values) {
    hit <- which(clean == tolower(value))
    if (length(hit) > 0L) return(names[[hit[[1L]]]])
  }
  NULL
}

.cs_other_measurement <- function(name, format) {
  original <- as.character(name)
  clean <- trimws(gsub("\\s+", " ", original))
  parts <- trimws(strsplit(clean, ":", fixed = TRUE)[[1L]])
  if (length(parts) >= 2L) {
    statistic <- .cs_qupath_statistic(parts[[length(parts)]])
    if (statistic %in% .cs_vocab_values("intensity_statistic")) {
      compartment <- if (length(parts) == 2L) "cell" else .cs_qupath_compartment(parts[[1L]])
      marker <- if (length(parts) == 2L) parts[[1L]] else paste(parts[2:(length(parts) - 1L)], collapse = ":")
      if (!is.null(compartment) && nzchar(marker) && !grepl(":", marker, fixed = TRUE)) {
        return(data.frame(
          source_name = original, kind = "intensity", marker = marker,
          compartment = compartment, statistic = statistic, unit = "a.u.",
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  suffix <- regexec("^(.+?)[ _](mean|median|sd|std[.]?dev[.]?|min|max|sum)$", clean, ignore.case = TRUE)
  match <- regmatches(clean, suffix)[[1L]]
  if (length(match) == 3L) {
    statistic <- .cs_qupath_statistic(match[[3L]])
    marker <- trimws(match[[2L]])
    if (statistic %in% .cs_vocab_values("intensity_statistic") &&
        nzchar(marker) && !grepl(":", marker, fixed = TRUE) &&
        !grepl("^(centroid|detection|cell type)$", marker, ignore.case = TRUE)) {
      return(data.frame(
        source_name = original, kind = "intensity", marker = marker,
        compartment = "cell", statistic = statistic, unit = "a.u.",
        stringsAsFactors = FALSE
      ))
    }
  }
  morphology <- c(
    area = "area", perimeter = "perimeter", circularity = "circularity",
    eccentricity = "eccentricity", solidity = "solidity",
    major_axis_length = "major_axis_length", minor_axis_length = "minor_axis_length",
    extent = "extent", orientation = "orientation", entropy = "other",
    iqr = "other", q25 = "other", q75 = "other"
  )
  key <- tolower(gsub("[^a-z0-9]+", "_", clean, perl = TRUE))
  if (key %in% names(morphology) && morphology[[key]] != "area") {
    statistic <- unname(morphology[[key]])
    kind <- if (statistic == "other") "other" else "shape"
    return(data.frame(
      source_name = original, kind = kind, marker = NA_character_,
      compartment = if (kind == "other") NA_character_ else "cell",
      statistic = statistic, unit = "1", stringsAsFactors = FALSE
    ))
  }
  NULL
}

.cs_other_apply_marker_map <- function(metadata, marker_map, call) {
  if (is.null(marker_map)) return(metadata)
  if (!is.data.frame(marker_map) || !identical(names(marker_map), c("from", "to"))) {
    .cs_other_abort("{.arg marker_map} must be created with {.fn cs_marker_map}.", call = call)
  }
  if (!is.null(metadata) && nrow(metadata) > 0L) {
    hit <- match(metadata$marker, marker_map$from)
    metadata$marker[!is.na(hit)] <- marker_map$to[hit[!is.na(hit)]]
  }
  metadata
}

.cs_other_detect <- function(path, n_max = 50L, call = rlang::caller_env()) {
  if (!file.exists(path) || dir.exists(path)) return(NULL)
  table <- tryCatch(.cs_other_data(path, call = call), error = function(e) NULL)
  if (is.null(table)) return(NULL)
  names_table <- names(table)
  id <- !is.null(.cs_other_find(names_table, c("cell_id", "cell id", "detection id", "object id", "id")))
  row <- !is.null(.cs_other_find(names_table, c(
    paste0("centroid_", "row"), paste0("centroid_", "row_px")
  )))
  col <- !is.null(.cs_other_find(names_table, c(
    paste0("centroid_", "col"), paste0("centroid_", "col_px")
  )))
  inform <- !is.null(.cs_other_find(names_table, c("cell x position"))) &&
    !is.null(.cs_other_find(names_table, c("cell y position"))) &&
    any(grepl("phenotype|compartment|mean|median|intensity", names_table, ignore.case = TRUE))
  suffix <- any(grepl("[ _](mean|median|sd|std[.]?dev[.]?|q25|q75|min|max)$", names_table, ignore.case = TRUE))
  if (id && row && col && suffix) {
    data.frame(
      format = c("segmantr", "mcquant"),
      score = c(0.95, 0.8),
      evidence = c(
        paste0("cell_id, centroid_", "row/centroid_", "col and channel statistic columns"),
        "cell_id and pixel centroid columns"
      ),
      stringsAsFactors = FALSE
    )
  } else if (id && row && col) {
    data.frame(
      format = "mcquant", score = 0.9,
      evidence = "cell identifier and pixel centroid columns",
      stringsAsFactors = FALSE
    )
  } else if (id && inform) {
    data.frame(
      format = "inform", score = 0.95,
      evidence = "inForm Cell ID and Cell X/Y Position columns",
      stringsAsFactors = FALSE
    )
  } else {
    NULL
  }
}

.cs_other_read <- function(path, format, pixel_size = NULL, image_id = NULL,
                           sample_id = NULL, marker_map = NULL,
                           keep_other = TRUE, keep_paths = FALSE, quiet = FALSE,
                           call = rlang::caller_env()) {
  .cs_check_path(path, call = call)
  table <- .cs_other_data(path, call = call)
  if (nrow(table) == 0L && ncol(table) == 0L) {
    .cs_other_abort("The input table has no columns.", call = call)
  }
  names_table <- names(table)
  id <- .cs_other_find(names_table, c("cell_id", "cell id", "detection id", "object id", "id"))
  if (is.null(id)) {
    .cs_other_abort("The input table has no cell identifier column.", call = call)
  }
  x_um <- .cs_other_find(names_table, c("x", "centroid_x_um", "centroid x um", "cell x position", "centroid x"))
  y_um <- .cs_other_find(names_table, c("y", "centroid_y_um", "centroid y um", "cell y position", "centroid y"))
  x_px <- .cs_other_find(names_table, c(
    paste0("centroid_", "col"), paste0("centroid_", "col_px"),
    "centroid x px", "x_px"
  ))
  y_px <- .cs_other_find(names_table, c(
    paste0("centroid_", "row"), paste0("centroid_", "row_px"),
    "centroid y px", "y_px"
  ))
  if (!is.null(x_um) && !is.null(y_um) && format == "inform") {
    unit <- "um"
    x <- x_um
    y <- y_um
  } else if (!is.null(x_px) && !is.null(y_px)) {
    unit <- "px"
    x <- x_px
    y <- y_px
  } else if (!is.null(x_um) && !is.null(y_um)) {
    unit <- "um"
    x <- x_um
    y <- y_um
  } else {
    .cs_other_abort(
      "The input table must contain both x and y coordinates in micrometres or pixels.",
      class = "cellspec_error_units", call = call
    )
  }
  if (unit == "px" && is.null(pixel_size)) {
    .cs_other_abort(
      "Pixel coordinates require {.arg pixel_size} in micrometres per pixel.",
      class = "cellspec_error_units", call = call
    )
  }
  if (format == "segmantr" &&
      (!identical(x, "centroid_col") || !identical(y, "centroid_row") || unit != "px")) { # nolint: cttir_domain_vocab
    .cs_other_abort(
      paste0("The segmantR adapter requires the one-based centroid_col/centroid_row ", # nolint: cttir_domain_vocab
             "convention from sg_extract_features(); use an explicit table map for other frames."),
      class = "cellspec_error_units", call = call
    )
  }
  image <- .cs_other_find(names_table, c("image", "image_id", "image id", "sample"))
  sample <- .cs_other_find(names_table, c("sample", "sample_id", "sample id"))
  area <- .cs_other_find(names_table, c("area", "area_um2", "area um2", "cell area"))
  excluded <- unique(c(id, x, y, x_um, y_um, x_px, y_px, image, sample, area))
  metadata <- lapply(setdiff(names_table, excluded), .cs_other_measurement, format = format)
  metadata <- metadata[!vapply(metadata, is.null, logical(1))]
  metadata <- if (length(metadata) == 0L) NULL else do.call(rbind, metadata)
  metadata <- .cs_other_apply_marker_map(metadata, marker_map, call)
  if (!is.null(metadata)) {
    if (format == "segmantr") {
      lengths <- metadata$kind == "shape" & metadata$statistic %in%
        c("perimeter", "major_axis_length", "minor_axis_length")
      metadata$unit[lengths] <- "px"
      metadata$unit[metadata$statistic == "orientation"] <- "rad"
    }
    metadata <- .cs_check_measurements(metadata, call = call)
  }
  map <- cs_column_map(
    cell_id = id,
    x = x,
    y = y,
    image_id = image,
    sample_id = sample,
    area = area,
    coordinate_unit = unit,
    measurements = metadata
  )
  source_path <- path
  if (grepl("\\.rds$", path, ignore.case = TRUE)) {
    source_path <- tempfile("cellspec-adapter-", fileext = ".tsv")
    on.exit(unlink(source_path), add = TRUE)
    data.table::fwrite(table, source_path, sep = "\t", quote = FALSE)
  }
  out <- cs_read(
    source_path, format = "table", pixel_size = pixel_size,
    image_id = image_id, sample_id = sample_id, column_map = map,
    keep_other = keep_other, keep_paths = keep_paths, quiet = quiet
  )
  if (format == "segmantr") {
    out$cells$x_px <- out$cells$x_px - 0.5
    out$cells$y_px <- out$cells$y_px - 0.5
    out$cells$x <- out$cells$x_px * pixel_size
    out$cells$y <- out$cells$y_px * pixel_size
    if (!is.null(area) && identical(tolower(area), "area")) {
      out$cells$area <- out$cells$area * pixel_size^2
    }
    out$provenance$parameters$coordinate_conversion <- list(
      source_frame = "one-based pixel-index means from sg_extract_features",
      destination_frame = "pixel-edge origin at top left of input image",
      index_offset = -0.5, pixel_size_um = pixel_size,
      area_scale = if (identical(tolower(area), "area")) pixel_size^2 else 1
    )
  }
  out$provenance$reader$adapter <- format
  out$provenance$reader$adapter_version <- if (format == "segmantr") "1.0.1" else "1.0.0"
  out$provenance$parameters$source_convention <- switch(
    format,
    mcquant = "MCQuant pixel or micrometre centroid columns",
    segmantr = paste0("segmantR centroid_", "row/centroid_", "col and channel_stat columns"),
    inform = "inForm cell segmentation table",
    format
  )
  if (!identical(source_path, path)) {
    info <- file.info(path)
    out$provenance$inputs <- list(list(
      path_basename = basename(path), bytes = as.numeric(info$size),
      sha256 = unname(.cs_sha256_file(path))
    ))
  }
  out <- .cs_add_history(out, step = "read", fun = "cs_read", details = list(
    format = format, n_cells = nrow(out$cells)
  ))
  cs_assert_valid(out, level = "structure", call = call)
  out
}

.cs_mcquant_read <- function(path, pixel_size = NULL, image_id = NULL,
                             sample_id = NULL, marker_map = NULL,
                             keep_other = TRUE, keep_paths = FALSE, quiet = FALSE,
                             call = rlang::caller_env()) {
  .cs_other_read(path, "mcquant", pixel_size, image_id, sample_id, marker_map,
                 keep_other, keep_paths, quiet, call)
}

.cs_segantr_read <- function(path, pixel_size = NULL, image_id = NULL,
                             sample_id = NULL, marker_map = NULL,
                             keep_other = TRUE, keep_paths = FALSE, quiet = FALSE,
                             call = rlang::caller_env()) {
  .cs_other_read(path, "segmantr", pixel_size, image_id, sample_id, marker_map,
                 keep_other, keep_paths, quiet, call)
}

.cs_inform_read <- function(path, pixel_size = NULL, image_id = NULL,
                            sample_id = NULL, marker_map = NULL,
                            keep_other = TRUE, keep_paths = FALSE, quiet = FALSE,
                            call = rlang::caller_env()) {
  .cs_other_read(path, "inform", pixel_size, image_id, sample_id, marker_map,
                 keep_other, keep_paths, quiet, call)
}
