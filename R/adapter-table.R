# Generic delimited-table adapter.

.cs_table_adapter_version <- "1.0.0"
.cs_table_mapping_names <- c("cell_id", "x", "y", "image_id", "sample_id", "area")
.cs_table_metadata_names <- c(
  "source_name", "kind", "marker", "compartment", "statistic", "unit"
)

.cs_table_abort <- function(message, call = rlang::caller_env()) {
  .cs_abort(
    message,
    class = "cellspec_error_format",
    call = call,
    .envir = parent.frame()
  )
}

.cs_table_mapping <- function(x, arg, allow_null = FALSE,
                             call = rlang::caller_env()) {
  if (allow_null && is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    .cs_table_abort(
      c(
        "{.arg {arg}} must be a single non-empty source-column name.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      call = call
    )
  }
  x
}

.cs_table_feature_id <- function(metadata, call = rlang::caller_env()) {
  is_intensity <- metadata$kind == "intensity"
  is_shape <- metadata$kind == "shape"
  ids <- rep(NA_character_, nrow(metadata))
  ids[is_intensity] <- paste(
    metadata$compartment[is_intensity],
    metadata$marker[is_intensity],
    metadata$statistic[is_intensity],
    sep = ":"
  )
  ids[is_shape] <- paste(
    metadata$compartment[is_shape], metadata$statistic[is_shape], sep = ":"
  )
  other <- metadata$kind == "other"
  if (any(other)) {
    source <- tolower(metadata$source_name[other])
    source <- gsub("[^a-z0-9]+", "_", source, perl = TRUE)
    source <- gsub("^_+|_+$", "", source, perl = TRUE)
    source[!nzchar(source)] <- "value"
    ids[other] <- paste0("other:", source)
  }
  if (anyNA(ids) || anyDuplicated(ids)) {
    .cs_table_abort(
      c(
        "The measurement metadata produces duplicated feature identifiers.",
        "x" = "Each mapped measurement must describe a unique feature."
      ),
      call = call
    )
  }
  ids
}

.cs_check_measurements <- function(measurements,
                                   call = rlang::caller_env()) {
  if (is.null(measurements)) {
    return(NULL)
  }
  if (!is.data.frame(measurements)) {
    .cs_table_abort(
      c(
        "{.arg measurements} must be a data frame.",
        "x" = "Got {.obj_type_friendly {measurements}}."
      ),
      call = call
    )
  }
  missing <- setdiff(.cs_table_metadata_names, names(measurements))
  if (length(missing) > 0L) {
    .cs_table_abort(
      c(
        "{.arg measurements} lacks required metadata columns.",
        "x" = "Add {.val {missing}}."
      ),
      call = call
    )
  }
  if (anyDuplicated(names(measurements))) {
    .cs_table_abort(
      "{.arg measurements} has duplicated metadata column names.",
      call = call
    )
  }

  metadata <- as.data.frame(measurements, stringsAsFactors = FALSE, optional = TRUE)
  for (nm in .cs_table_metadata_names) {
    value <- metadata[[nm]]
    if (is.factor(value) || (is.logical(value) && all(is.na(value)))) {
      value <- as.character(value)
    }
    if (!is.character(value)) {
      .cs_table_abort(
        c(
          "Metadata column {.field {nm}} must be character.",
          "x" = "Got {.obj_type_friendly {value}}."
        ),
        call = call
      )
    }
    metadata[[nm]] <- value
  }

  blank_source <- is.na(metadata$source_name) | !nzchar(metadata$source_name)
  if (any(blank_source) || anyDuplicated(metadata$source_name)) {
    .cs_table_abort(
      "Measurement source names must be non-empty and unique.",
      call = call
    )
  }
  bad_kind <- is.na(metadata$kind) | !metadata$kind %in% .cs_vocab_values("kind")
  if (any(bad_kind)) {
    .cs_table_abort(
      c(
        "Measurement metadata has an unknown {.field kind}.",
        "x" = "Use {.val {(.cs_vocab_values(\"kind\"))}}."
      ),
      call = call
    )
  }

  is_intensity <- metadata$kind == "intensity"
  is_shape <- metadata$kind == "shape"
  is_other <- metadata$kind == "other"
  marker_blank <- is.na(metadata$marker) | !nzchar(metadata$marker)
  bad_marker <- (is_intensity & marker_blank) |
    (!is_intensity & !is.na(metadata$marker))
  bad_marker <- bad_marker | (!is.na(metadata$marker) &
    (metadata$marker != trimws(metadata$marker) |
      grepl(":", metadata$marker, fixed = TRUE)))
  if (any(bad_marker)) {
    .cs_table_abort(
      "Intensity metadata needs a trimmed marker without `:`, while shape and other metadata need `NA` for {.field marker}.",
      call = call
    )
  }

  compartments <- .cs_vocab_values("compartment")
  bad_compartment <- (is_intensity | is_shape) &
    (is.na(metadata$compartment) | !metadata$compartment %in% compartments)
  bad_compartment <- bad_compartment | (!is.na(metadata$compartment) &
    !metadata$compartment %in% compartments)
  if (any(bad_compartment)) {
    .cs_table_abort(
      c(
        "Intensity and shape metadata need a known {.field compartment}.",
        "x" = "Use the known compartment vocabulary or `NA` for other features."
      ),
      call = call
    )
  }

  bad_statistic <- is.na(metadata$statistic) | !nzchar(metadata$statistic)
  bad_statistic <- bad_statistic | (is_intensity &
    !metadata$statistic %in% .cs_vocab_values("intensity_statistic"))
  bad_statistic <- bad_statistic | (is_shape &
    !metadata$statistic %in% .cs_vocab_values("shape_statistic"))
  if (any(bad_statistic)) {
    .cs_table_abort(
      "Measurement statistics do not match their declared {.field kind}.",
      call = call
    )
  }

  if (anyNA(metadata$unit) || any(!metadata$unit %in% .cs_vocab_values("unit"))) {
    .cs_table_abort(
      c(
        "Measurement metadata has an unknown {.field unit}.",
        "x" = "Use {.val {(.cs_vocab_values(\"unit\"))}}."
      ),
      call = call
    )
  }
  metadata[.cs_table_metadata_names]
}

.cs_table_read <- function(path, n_max = NULL, call = rlang::caller_env()) {
  compressed <- grepl("\\.gz$", path, ignore.case = TRUE)
  args <- list(
    header = TRUE,
    data.table = FALSE,
    check.names = FALSE,
    encoding = "UTF-8",
    showProgress = FALSE,
    na.strings = c("", "NA")
  )
  if (!is.null(n_max)) args$nrows <- as.integer(n_max)
  if (compressed && .Platform$OS.type != "windows") {
    args$cmd <- paste("gzip -dc --", shQuote(path))
  } else if (!compressed) {
    args$file <- path
  }
  result <- tryCatch(
    if (compressed && .Platform$OS.type == "windows") {
      utils::read.delim(
        gzfile(path, open = "rt", encoding = "UTF-8"),
        header = TRUE,
        check.names = FALSE,
        nrows = if (is.null(n_max)) -1L else as.integer(n_max),
        na.strings = c("", "NA"),
        stringsAsFactors = FALSE
      )
    } else {
      suppressWarnings(do.call(data.table::fread, args))
    },
    error = function(error) error
  )
  if (inherits(result, "error")) {
    .cs_table_abort(
      c(
        "Could not read {.path {basename(path)}} as a delimited table.",
        "x" = conditionMessage(result)
      ),
      call = call
    )
  }
  as.data.frame(result, stringsAsFactors = FALSE, optional = TRUE)
}

.cs_table_numeric <- function(value, source_name, call = rlang::caller_env()) {
  if (is.numeric(value)) {
    return(as.double(value))
  }
  if (is.logical(value) && all(is.na(value))) {
    return(as.double(value))
  }
  if (!is.character(value)) {
    .cs_table_abort(
      c(
        "Mapped measurement or coordinate {.field {source_name}} is not numeric.",
        "x" = "Got {.obj_type_friendly {value}}."
      ),
      call = call
    )
  }
  converted <- suppressWarnings(as.numeric(value))
  bad <- is.na(converted) & !is.na(value) & nzchar(trimws(value))
  if (any(bad)) {
    .cs_table_abort(
      c(
        "Mapped measurement or coordinate {.field {source_name}} is not numeric.",
        "x" = "Could not parse values in rows {.val {which(bad)}}."
      ),
      call = call
    )
  }
  converted
}

.cs_table_character <- function(value, source_name, call = rlang::caller_env()) {
  if (!(is.atomic(value) && !is.list(value))) {
    .cs_table_abort(
      "Mapped identifier {.field {source_name}} must be an atomic column.",
      call = call
    )
  }
  as.character(value)
}

.cs_table_require_ids <- function(value, name, call = rlang::caller_env()) {
  blank <- is.na(value) | !nzchar(trimws(value))
  if (any(blank)) {
    .cs_table_abort(
      c(
        "Mapped {.field {name}} contains missing or empty identifiers.",
        "x" = "Rows {.val {which(blank)}} cannot be assigned an identifier."
      ),
      call = call
    )
  }
  invisible(value)
}

.cs_table_derived_image_id <- function(path) {
  value <- basename(path)
  value <- sub("\\.[Gg][Zz]$", "", value)
  value <- sub("\\.[^.]+$", "", value)
  if (!nzchar(value)) basename(path) else value
}

.cs_table_metadata_other <- function(source_names) {
  if (length(source_names) == 0L) {
    return(data.frame(
      source_name = character(), kind = character(), marker = character(),
      compartment = character(), statistic = character(), unit = character(),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    source_name = source_names,
    kind = rep("other", length(source_names)),
    marker = rep(NA_character_, length(source_names)),
    compartment = rep(NA_character_, length(source_names)),
    statistic = source_names,
    unit = rep("1", length(source_names)),
    stringsAsFactors = FALSE
  )
}

#' List the available cellspec readers
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists the adapters implemented by this build of cellspecR. The generic
#' table adapter accepts delimited files when the source columns are mapped
#' explicitly with [cs_column_map()].
#'
#' @return A data frame with `format`, `adapter_version`, `description`,
#'   `tested_with` and `status` columns.
#' @family adapters
#' @seealso [cs_detect_format()], [cs_column_map()], [cs_read()]
#' @export
#' @examples
#' cs_formats()
cs_formats <- function() {
  rows <- list(data.frame(
    format = "table",
    adapter_version = .cs_table_adapter_version,
    description = "Generic delimited table with an explicit column map.",
    tested_with = "CSV, TSV and gzip-compressed delimited files",
    status = "stable",
    stringsAsFactors = FALSE
  ))
  optional <- list(
    qupath = c("QuPath colon-delimited measurement export", "QuPath 0.6.0 and 0.7.0"),
    qupath_tiled = c("Tiled QuPath tables with centroid ownership", "QuPath 0.7.0"),
    mcquant = c("MCMICRO MCQuant measurement export", "MCMICRO/MCQuant"),
    segmantr = c("segmantR feature table", "segmantR 0.5"),
    inform = c("inForm cell segmentation data", "inForm/phenoptr")
  )
  for (format in names(optional)) {
    rows[[length(rows) + 1L]] <- data.frame(
      format = format,
      adapter_version = "1.0.0",
      description = optional[[format]][[1L]],
      tested_with = optional[[format]][[2L]],
      status = "experimental",
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

#' Detect the generic table format
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads only the header and at most `n_max` data rows. A generic table is
#' deliberately returned as a low-confidence candidate because its biological
#' meaning cannot be inferred safely without an explicit column map.
#'
#' @param path A delimited table file.
#' @param n_max Maximum number of data rows to inspect after the header.
#' @return A data frame with `format`, `score` and `evidence` columns.
#' @family adapters
#' @seealso [cs_column_map()], [cs_read()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(id = 1, x = 2, y = 3), path, row.names = FALSE)
#' cs_detect_format(path)
cs_detect_format <- function(path, n_max = 50L) {
  call <- rlang::caller_env()
  .cs_check_path(path, call = call)
  .cs_check_count(n_max, min = 0L, arg = "n_max", call = call)
  if (dir.exists(path)) {
    candidates <- if (exists(".cs_tiled_detect", mode = "function")) {
      .cs_tiled_detect(path, n_max = n_max, call = call)
    } else {
      NULL
    }
    if (is.null(candidates) || nrow(candidates) == 0L) {
      .cs_table_abort(
        "The directory does not match a supported reader layout.",
        call = call
      )
    }
    return(candidates)
  }
  table <- tryCatch(
    .cs_table_read(path, n_max = n_max, call = call),
    error = function(error) NULL
  )
  if (is.null(table) && exists(".cs_other_detect", mode = "function")) {
    other <- .cs_other_detect(path, n_max = n_max, call = call)
    if (!is.null(other)) return(other)
    .cs_table_abort("Could not read the input as a supported delimited table.", call = call)
  }
  if (is.null(table)) {
    .cs_table_abort("Could not read the input as a delimited table.", call = call)
  }
  if (length(names(table)) == 0L) {
    .cs_table_abort("The delimited table has no columns.", call = call)
  }
  evidence <- paste0(
    "Readable delimited table with ", length(names(table)),
    " column", if (length(names(table)) == 1L) "" else "s",
    "; explicit column_map required"
  )
  generic <- data.frame(
    format = "table",
    score = 0.5,
    evidence = evidence,
    stringsAsFactors = FALSE
  )
  specialized <- list()
  if (exists(".cs_qupath_detect", mode = "function")) {
    qupath <- .cs_qupath_detect(path, n_max = n_max, call = call)
    if (!is.null(qupath)) specialized[[length(specialized) + 1L]] <- qupath
  }
  if (exists(".cs_other_detect", mode = "function")) {
    other <- .cs_other_detect(path, n_max = n_max, call = call)
    if (!is.null(other)) specialized[[length(specialized) + 1L]] <- other
  }
  do.call(rbind, c(specialized, list(generic)))
}

#' Validate a table column map
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates a validated description of how a generic delimited table maps to
#' the cellspec columns. Source names are checked for shape here and checked
#' against the input table by [cs_read()].
#'
#' @param cell_id Source column containing the cell identifier.
#' @param x Source column containing the x coordinate.
#' @param y Source column containing the y coordinate.
#' @param image_id Optional source column containing image identifiers.
#' @param sample_id Optional source column containing sample identifiers.
#' @param area Optional source column containing positive cell areas.
#' @param coordinate_unit Coordinate unit for `x` and `y`: micrometres or
#'   pixels.
#' @param measurements Optional data frame with `source_name`, `kind`,
#'   `marker`, `compartment`, `statistic` and `unit` metadata columns.
#' @return An object of class `cs_column_map`, a named list with the mapped
#'   source names, coordinate unit and validated measurement metadata.
#' @family adapters
#' @seealso [cs_read()]
#' @export
#' @examples
#' cs_column_map(
#'   "Cell ID", "Centroid X", "Centroid Y",
#'   measurements = data.frame(
#'     source_name = "CD3e Mean", kind = "intensity", marker = "CD3e",
#'     compartment = "cell", statistic = "mean", unit = "a.u."
#'   )
#' )
cs_column_map <- function(cell_id, x, y, image_id = NULL, sample_id = NULL,
                          area = NULL, coordinate_unit = c("um", "px"),
                          measurements = NULL) {
  call <- rlang::caller_env()
  if (length(coordinate_unit) > 1L &&
      identical(coordinate_unit, c("um", "px"))) {
    coordinate_unit <- coordinate_unit[[1L]]
  }
  if (!is.character(coordinate_unit) || length(coordinate_unit) != 1L ||
      is.na(coordinate_unit) || !coordinate_unit %in% c("um", "px")) {
    .cs_table_abort(
      c(
        "{.arg coordinate_unit} must be {.val \"um\"} or {.val \"px\"}.",
        "x" = "Got {.obj_type_friendly {coordinate_unit}}."
      ),
      call = call
    )
  }
  mapped <- list(
    cell_id = .cs_table_mapping(cell_id, "cell_id", call = call),
    x = .cs_table_mapping(x, "x", call = call),
    y = .cs_table_mapping(y, "y", call = call),
    image_id = .cs_table_mapping(image_id, "image_id", allow_null = TRUE, call = call),
    sample_id = .cs_table_mapping(sample_id, "sample_id", allow_null = TRUE, call = call),
    area = .cs_table_mapping(area, "area", allow_null = TRUE, call = call),
    coordinate_unit = coordinate_unit,
    measurements = .cs_check_measurements(measurements, call = call)
  )
  source_names <- unname(unlist(mapped[.cs_table_mapping_names], use.names = FALSE))
  source_names <- source_names[!is.na(source_names)]
  if (anyDuplicated(source_names)) {
    .cs_table_abort(
      "Each source column can be used by only one cellspec mapping.",
      call = call
    )
  }
  if (!is.null(mapped$measurements)) {
    measurement_names <- mapped$measurements$source_name
    if (any(measurement_names %in% source_names)) {
      .cs_table_abort(
        "A source column cannot be both a cellspec field and a measurement.",
        call = call
      )
    }
    .cs_table_feature_id(mapped$measurements, call = call)
  }
  structure(mapped, class = c("cs_column_map", "list"))
}

#' Read a delimited table into a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reads a generic delimited cell table using an explicit [cs_column_map()].
#' Only `format = "table"` is implemented in this adapter; specialized
#' formats remain extension points for future adapters.
#'
#' @param path One delimited table file.
#' @param format Reader format. Use `"table"` for this adapter or `"auto"`
#'   to request conservative detection.
#' @param pixel_size Micrometres per pixel. Required for pixel coordinates;
#'   micrometre-coordinate tables use `1` when no calibration is supplied.
#' @param image_id Optional scalar image identifier overriding the mapped
#'   column; otherwise the mapped column or file basename is used.
#' @param sample_id Optional scalar sample identifier overriding the mapped
#'   column; otherwise the mapped column or image identifier is used.
#' @param marker_map Reserved for future adapters; not used by the table
#'   adapter.
#' @param column_map A validated object returned by [cs_column_map()].
#' @param tile_bounds Optional tile-bound data frame for `format =
#'   "qupath_tiled"`, with `tile_id`, `xmin`, `xmax`, `ymin` and `ymax` in
#'   micrometres.
#' @param verify_done Whether tiled readers should verify optional `.done.tsv`
#'   metadata against each source file.
#' @param keep_other Whether unmapped numeric columns become `other`
#'   measurements and other unmapped columns are retained in `cells`.
#' @param keep_paths Whether the full input path may be recorded in
#'   provenance.
#' @param quiet Reserved for consistency with future readers; suppresses the
#'   informational warning about dropped columns when `keep_other = FALSE`.
#' @return A validated `cellspec` object.
#' @family adapters
#' @seealso [cs_formats()], [cs_detect_format()], [cs_column_map()]
#' @export
#' @examples
#' path <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(id = c("c1", "c2"), x = 1:2, y = 3:4),
#'                  path, row.names = FALSE)
#' map <- cs_column_map("id", "x", "y")
#' x <- cs_read(path, format = "table", column_map = map)
#' dim(x)
cs_read <- function(path, format = "auto", pixel_size = NULL, image_id = NULL,
                    sample_id = NULL, marker_map = NULL, column_map = NULL,
                    tile_bounds = NULL, verify_done = TRUE, keep_other = TRUE,
                    keep_paths = FALSE, quiet = FALSE) {
  call <- rlang::caller_env()
  .cs_check_path(path, call = call)
  if (!is.character(format) || length(format) != 1L || is.na(format) ||
      !nzchar(format)) {
    .cs_table_abort("{.arg format} must be a non-empty string.", call = call)
  }
  .cs_check_string(image_id, allow_null = TRUE, arg = "image_id", call = call)
  .cs_check_string(sample_id, allow_null = TRUE, arg = "sample_id", call = call)
  .cs_check_flag(keep_other, arg = "keep_other", call = call)
  .cs_check_flag(verify_done, arg = "verify_done", call = call)
  .cs_check_flag(keep_paths, arg = "keep_paths", call = call)
  .cs_check_flag(quiet, arg = "quiet", call = call)
  .cs_check_number(pixel_size, allow_null = TRUE, min = 0, arg = "pixel_size", call = call)
  if (!is.null(pixel_size) && pixel_size <= 0) {
    .cs_abort(
      "{.arg pixel_size} must be positive.",
      class = "cellspec_error_units",
      call = call
    )
  }
  if (!is.null(marker_map)) {
    if (!is.data.frame(marker_map) || !identical(names(marker_map), c("from", "to"))) {
      .cs_table_abort(
        "{.arg marker_map} must be created with {.fn cs_marker_map}.",
        call = call
      )
    }
  }

  if (identical(format, "auto")) {
    candidates <- cs_detect_format(path)
    top <- max(candidates$score)
    close <- which(candidates$score >= top - 0.1)
    decisive <- top >= 0.9 && length(close) == 1L
    if (!decisive) {
      .cs_abort(
        c(
          "The input format cannot be selected automatically.",
          "x" = "Candidate formats: {.val {candidates$format[close]}}; scores: {.val {candidates$score[close]}}.",
          "i" = "Supply an explicit {.arg format}."
        ),
        class = "cellspec_error_ambiguous_format",
        call = call
      )
    }
    format <- candidates$format[[close[[1L]]]]
  }
  if (identical(format, "qupath") && exists(".cs_qupath_read", mode = "function")) {
    return(.cs_qupath_read(
      path = path, pixel_size = pixel_size, image_id = image_id,
      sample_id = sample_id, marker_map = marker_map,
      keep_other = keep_other, keep_paths = keep_paths, quiet = quiet,
      call = call
    ))
  }
  if (identical(format, "qupath_tiled") && exists(".cs_tiled_read", mode = "function")) {
    return(.cs_tiled_read(
      path = path, pixel_size = pixel_size, image_id = image_id,
      sample_id = sample_id, marker_map = marker_map,
      tile_bounds = tile_bounds, verify_done = verify_done,
      keep_other = keep_other, keep_paths = keep_paths, quiet = quiet,
      call = call
    ))
  }
  specialized <- list(
    mcquant = ".cs_mcquant_read",
    segmantr = ".cs_segantr_read",
    inform = ".cs_inform_read"
  )
  if (format %in% names(specialized) && exists(specialized[[format]], mode = "function")) {
    reader <- get(specialized[[format]], mode = "function")
    return(reader(
      path = path, pixel_size = pixel_size, image_id = image_id,
      sample_id = sample_id, marker_map = marker_map,
      keep_other = keep_other, keep_paths = keep_paths, quiet = quiet,
      call = call
    ))
  }
  if (!identical(format, "table")) {
    .cs_table_abort(
      c(
        "The requested format is not implemented.",
        "x" = "Format {.val {format}} is unsupported by this build."
      ),
      call = call
    )
  }
  map_names <- c(.cs_table_mapping_names, "coordinate_unit", "measurements")
  map_valid <- inherits(column_map, "cs_column_map") &&
    all(map_names %in% names(column_map)) &&
    all(vapply(c("cell_id", "x", "y"), function(name) {
      is.character(column_map[[name]]) && length(column_map[[name]]) == 1L &&
        !is.na(column_map[[name]]) && nzchar(column_map[[name]])
    }, logical(1))) &&
    is.character(column_map$coordinate_unit) &&
    length(column_map$coordinate_unit) == 1L &&
    !is.na(column_map$coordinate_unit) &&
    column_map$coordinate_unit %in% c("um", "px")
  if (!map_valid) {
    .cs_table_abort(
      "{.arg column_map} must be created with {.fn cs_column_map} for {.val \"table\"} input.",
      call = call
    )
  }
  if (dir.exists(path)) {
    .cs_table_abort(
      "The table adapter reads one delimited file; directory adapters are not implemented.",
      call = call
    )
  }

  table <- .cs_table_read(path, call = call)
  if (anyDuplicated(names(table))) {
    .cs_table_abort("The delimited table has duplicated column names.", call = call)
  }
  metadata <- column_map$measurements
  mapped <- unname(unlist(column_map[.cs_table_mapping_names], use.names = FALSE))
  mapped <- mapped[!is.na(mapped)]
  measurement_names <- if (is.null(metadata)) character() else metadata$source_name
  required_sources <- unique(c(mapped, measurement_names))
  missing <- setdiff(required_sources, names(table))
  if (length(missing) > 0L) {
    .cs_table_abort(
      c(
        "The delimited table lacks mapped source columns.",
        "x" = "Missing {.val {missing}}."
      ),
      call = call
    )
  }

  n <- nrow(table)
  cell_id <- .cs_table_character(table[[column_map$cell_id]], column_map$cell_id, call = call)
  .cs_table_require_ids(cell_id, "cell_id", call = call)
  x_raw <- .cs_table_numeric(table[[column_map$x]], column_map$x, call = call)
  y_raw <- .cs_table_numeric(table[[column_map$y]], column_map$y, call = call)
  if (any(!is.finite(x_raw)) || any(!is.finite(y_raw))) {
    .cs_abort(
      "Mapped pixel or micrometre coordinates must be finite.",
      class = "cellspec_error_units",
      call = call
    )
  }

  if (!is.null(image_id)) {
    image_ids <- rep(image_id, n)
  } else if (!is.null(column_map$image_id)) {
    image_ids <- .cs_table_character(
      table[[column_map$image_id]], column_map$image_id, call = call
    )
  } else {
    image_ids <- rep(.cs_table_derived_image_id(path), n)
  }
  if (!is.null(sample_id)) {
    sample_ids <- rep(sample_id, n)
  } else if (!is.null(column_map$sample_id)) {
    sample_ids <- .cs_table_character(
      table[[column_map$sample_id]], column_map$sample_id, call = call
    )
  } else {
    sample_ids <- image_ids
  }
  .cs_table_require_ids(image_ids, "image_id", call = call)
  .cs_table_require_ids(sample_ids, "sample_id", call = call)

  if (identical(column_map$coordinate_unit, "px")) {
    if (is.null(pixel_size)) {
      .cs_abort(
        "Pixel coordinates require {.arg pixel_size} in micrometres per pixel.",
        class = "cellspec_error_units",
        call = call
      )
    }
    x <- x_raw * pixel_size
    y <- y_raw * pixel_size
    if (any(!is.finite(x)) || any(!is.finite(y))) {
      .cs_abort(
        "Pixel coordinates overflow after conversion with {.arg pixel_size}.",
        class = "cellspec_error_units",
        call = call
      )
    }
  } else {
    x <- x_raw
    y <- y_raw
  }

  cells <- data.frame(
    cell_id = cell_id,
    image_id = image_ids,
    sample_id = sample_ids,
    x = x,
    y = y,
    stringsAsFactors = FALSE
  )
  if (!is.null(column_map$area)) {
    area <- .cs_table_numeric(table[[column_map$area]], column_map$area, call = call)
    if (any(!is.na(area) & !(is.finite(area) & area > 0))) {
      .cs_table_abort(
        "Mapped {.field area} must be positive or `NA`.",
        call = call
      )
    }
    cells$area <- area
  }
  if (identical(column_map$coordinate_unit, "px")) {
    cells$x_px <- x_raw
    cells$y_px <- y_raw
  }

  all_explicit <- unique(c(mapped, measurement_names))
  extra <- setdiff(names(table), all_explicit)
  numeric_extra <- extra[vapply(table[extra], is.numeric, logical(1))]
  other_metadata <- if (isTRUE(keep_other)) {
    .cs_table_metadata_other(numeric_extra)
  } else {
    .cs_table_metadata_other(character())
  }
  metadata <- if (is.null(metadata)) {
    other_metadata
  } else if (isTRUE(keep_other) && nrow(other_metadata) > 0L) {
    rbind(metadata, other_metadata)
  } else {
    metadata
  }
  if (!is.null(metadata) && nrow(metadata) > 0L) {
    metadata <- .cs_check_measurements(metadata, call = call)
  }
  feature_ids <- if (is.null(metadata) || nrow(metadata) == 0L) {
    character()
  } else {
    .cs_table_feature_id(metadata, call = call)
  }
  measurements <- if (length(feature_ids) == 0L) {
    matrix(numeric(0), nrow = n, ncol = 0L)
  } else {
    values <- lapply(metadata$source_name, function(source_name) {
      .cs_table_numeric(table[[source_name]], source_name, call = call)
    })
    out <- matrix(
      unlist(values, use.names = FALSE),
      nrow = n,
      ncol = length(values),
      dimnames = list(NULL, feature_ids)
    )
    storage.mode(out) <- "double"
    out
  }
  if (length(feature_ids) == 0L) {
    dimnames(measurements) <- list(NULL, NULL)
  }

  non_numeric_extra <- setdiff(extra, numeric_extra)
  reserved_cells <- c("cell_id", "image_id", "sample_id", "x", "y", "area", "x_px", "y_px")
  reserved_extra <- intersect(non_numeric_extra, reserved_cells)
  if (length(reserved_extra) > 0L && isTRUE(keep_other)) {
    .cs_table_abort(
      c(
        "Unmapped table columns use reserved cellspec names.",
        "x" = "Map {.val {reserved_extra}} explicitly or set {.arg keep_other} to `FALSE`."
      ),
      call = call
    )
  }
  if (isTRUE(keep_other)) {
    for (source_name in non_numeric_extra) {
      if (!source_name %in% reserved_cells) {
        cells[[source_name]] <- table[[source_name]]
      }
    }
  } else if (length(extra) > 0L && !isTRUE(quiet)) {
    .cs_warn(
      c(
        "Dropped unmapped table columns.",
        "i" = "Set {.arg keep_other} to `TRUE` to retain {.val {extra}}."
      ),
      class = "cellspec_warning"
    )
  }

  image_rows <- data.frame(
    image_id = image_ids,
    sample_id = sample_ids,
    pixel_size = rep(if (is.null(pixel_size)) 1 else pixel_size, n),
    source_image = rep(basename(path), n),
    stringsAsFactors = FALSE
  )
  if (nrow(image_rows) > 0L) {
    image_rows <- image_rows[!duplicated(image_rows[c("image_id", "sample_id")]), , drop = FALSE]
    if (anyDuplicated(image_rows$image_id)) {
      .cs_table_abort(
        "One image identifier is associated with multiple sample identifiers.",
        call = call
      )
    }
  }
  images <- image_rows
  marker_values <- if (is.null(metadata) || nrow(metadata) == 0L) {
    character()
  } else {
    unique(metadata$marker[metadata$kind == "intensity"])
  }
  marker_values <- marker_values[!is.na(marker_values)]
  channels <- if (length(marker_values) == 0L || nrow(images) == 0L) {
    .cs_empty_df("channels")
  } else {
    data.frame(
      image_id = rep(images$image_id, each = length(marker_values)),
      channel_index = rep(seq_along(marker_values), times = nrow(images)),
      channel_name = rep(marker_values, times = nrow(images)),
      marker = rep(marker_values, times = nrow(images)),
      stringsAsFactors = FALSE
    )
  }
  dictionary <- if (is.null(metadata) || nrow(metadata) == 0L) {
    .cs_empty_df("dictionary")
  } else {
    data.frame(
      feature_id = feature_ids,
      kind = metadata$kind,
      marker = metadata$marker,
      compartment = metadata$compartment,
      statistic = metadata$statistic,
      unit = metadata$unit,
      source_name = metadata$source_name,
      stringsAsFactors = FALSE
    )
  }

  object <- .cs_build(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    adapter = "table"
  )
  object$provenance$reader$adapter_version <- .cs_table_adapter_version
  info <- file.info(path)
  object$provenance$inputs <- list(list(
    path_basename = basename(path),
    bytes = as.numeric(info$size),
    sha256 = unname(.cs_sha256_file(path))
  ))
  object$provenance$parameters <- list(
    coordinate_unit = column_map$coordinate_unit,
    pixel_size_source = if (is.null(pixel_size)) "default" else "argument",
    keep_other = keep_other
  )
  if (isTRUE(keep_paths)) {
    object$provenance$parameters$local_paths <- path
  }
  object <- .cs_add_history(
    object,
    step = "read",
    fun = "cs_read",
    details = list(format = "table", n_cells = n)
  )
  cs_assert_valid(object, level = "structure", call = call)
  object
}
