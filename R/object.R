# The cellspec object: constructor, normalisation helpers and accessors.

#' Create a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Builds a `cellspec` object from its components and checks it against the
#' structure rules of the specification. Tool exports are normally read with
#' `cs_read()`; use `cs_new()` when you already hold the pieces in memory, for
#' example in another package that produces cell tables.
#'
#' Inputs are normalised before validation: any data frame subclass becomes a
#' plain `data.frame` without row names, factors become character vectors,
#' identifier columns (`cell_id`, `image_id`, `sample_id`, `subject_id`) are
#' converted to character, whole-number doubles in integer columns become
#' integers, and `NaN`/`Inf` in `measurements` become `NA` (counted in
#' `provenance$counts$nonfinite_converted`). A missing `sample_id` column in
#' `cells` is filled from `images`.
#'
#' @param cells A data frame with one row per cell and at least the columns
#'   `cell_id`, `image_id`, `sample_id` (or a `sample_id` in `images`), `x` and
#'   `y` (centroids in micrometres).
#' @param measurements A numeric matrix (or data frame of numeric columns) with
#'   one row per cell, in the row order of `cells`, and column names equal to
#'   `dictionary$feature_id`. `NULL` means no features.
#' @param dictionary A data frame describing each measurement column (see
#'   [cs_vocabulary()]). `NULL` is allowed only when there are no features.
#' @param images A data frame with one row per image and at least `image_id`,
#'   `sample_id` and `pixel_size`.
#' @param channels A data frame with one row per image and channel
#'   (`image_id`, `channel_index`, `channel_name`, `marker`), or `NULL` when no
#'   intensity features exist.
#' @param provenance A list describing the origin of the data. Missing fields
#'   are filled with defaults; `NULL` records the object as built by
#'   `cs_new()`.
#' @param adjacency Optional data frame of cell-cell contacts
#'   (`image_id`, `cell_id_a`, `cell_id_b`, `shared_boundary`, `method`).
#'
#' @return A `cellspec` object: a list of class `"cellspec"` with elements
#'   `spec_version` (string), `cells` (data frame), `measurements` (double
#'   matrix), `dictionary`, `images`, `channels` (data frames), `provenance`
#'   (list) and `adjacency` (data frame or `NULL`).
#' @family object
#' @seealso `vignette("specification", package = "cellspecR")` for every
#'   column and rule; [cs_validate()] for the checks applied.
#' @export
#' @examples
#' cells <- data.frame(
#'   cell_id = c("1", "2", "3"),
#'   image_id = "img1",
#'   sample_id = "s1",
#'   x = c(10, 20, 30),
#'   y = c(5, 15, 25),
#'   area = c(50, 62.5, 48)
#' )
#' measurements <- cbind(
#'   "cell:CD3e:mean" = c(120, 8, 95),
#'   "nucleus:FOXP3:mean" = c(3, 1, 40)
#' )
#' dictionary <- data.frame(
#'   feature_id = colnames(measurements),
#'   kind = "intensity",
#'   marker = c("CD3e", "FOXP3"),
#'   compartment = c("cell", "nucleus"),
#'   statistic = "mean",
#'   unit = "a.u.",
#'   source_name = c("Cell: CD3e: Mean", "Nucleus: FOXP3: Mean")
#' )
#' images <- data.frame(image_id = "img1", sample_id = "s1", pixel_size = 0.5)
#' channels <- data.frame(
#'   image_id = "img1",
#'   channel_index = 1:3,
#'   channel_name = c("DAPI", "CD3e", "FOXP3"),
#'   marker = c("DAPI", "CD3e", "FOXP3")
#' )
#' x <- cs_new(cells, measurements, dictionary, images, channels)
#' x
cs_new <- function(cells,
                   measurements = NULL,
                   dictionary = NULL,
                   images,
                   channels = NULL,
                   provenance = NULL,
                   adjacency = NULL) {
  rlang::check_required(cells)
  rlang::check_required(images)
  x <- .cs_build(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    provenance = provenance,
    adjacency = adjacency,
    adapter = "cs_new"
  )
  cs_assert_valid(x, level = "structure")
}

# Normalise components and assemble the object without validating it. Adapters
# and tests use this directly; user-facing entry points validate afterwards.
.cs_build <- function(cells,
                      measurements = NULL,
                      dictionary = NULL,
                      images,
                      channels = NULL,
                      provenance = NULL,
                      adjacency = NULL,
                      adapter = "cs_new",
                      call = rlang::caller_env()) {
  .cs_check_data_frame(cells, call = call)
  .cs_check_data_frame(images, call = call)
  .cs_check_data_frame(dictionary, allow_null = TRUE, call = call)
  .cs_check_data_frame(channels, allow_null = TRUE, call = call)
  .cs_check_data_frame(adjacency, allow_null = TRUE, call = call)
  if (!is.null(provenance) && !is.list(provenance)) {
    .cs_abort(
      c("{.arg provenance} must be a list or {.code NULL}.",
        "x" = "Got {.obj_type_friendly {provenance}}."),
      call = call
    )
  }

  images <- .cs_normalise_df(images, "images")
  cells <- .cs_normalise_df(cells, "cells")
  if (!"sample_id" %in% names(cells) && all(c("image_id", "sample_id") %in% names(images)) &&
    "image_id" %in% names(cells)) {
    cells$sample_id <- images$sample_id[match(cells$image_id, images$image_id)]
  }

  measurements <- .cs_normalise_measurements(measurements, nrow(cells), call = call)
  nonfinite <- attr(measurements, "cs_nonfinite")
  attr(measurements, "cs_nonfinite") <- NULL

  if (is.null(dictionary)) {
    if (ncol(measurements) > 0L) {
      .cs_abort(
        c("{.arg dictionary} is required when {.arg measurements} has columns.",
          "i" = "Describe each of the {ncol(measurements)} measurement column{?s} with one dictionary row."),
        call = call
      )
    }
    dictionary <- .cs_empty_df("dictionary")
  }
  dictionary <- .cs_normalise_df(dictionary, "dictionary")
  if (!"marker_source" %in% names(dictionary)) {
    dictionary$marker_source <- rep(NA_character_, nrow(dictionary))
  }

  channels <- if (is.null(channels)) .cs_empty_df("channels") else channels
  channels <- .cs_normalise_df(channels, "channels")
  if (!is.null(adjacency)) {
    adjacency <- .cs_normalise_df(adjacency, "adjacency")
  }

  provenance <- .cs_default_provenance(
    provenance,
    adapter = adapter,
    n = nrow(cells),
    nonfinite = nonfinite
  )

  .cs_new_object(
    cells = cells,
    measurements = measurements,
    dictionary = dictionary,
    images = images,
    channels = channels,
    provenance = provenance,
    adjacency = adjacency
  )
}

.cs_new_object <- function(cells, measurements, dictionary, images, channels,
                           provenance, adjacency = NULL,
                           spec_version = .cs_spec_version) {
  structure(
    list(
      spec_version = spec_version,
      cells = cells,
      measurements = measurements,
      dictionary = dictionary,
      images = images,
      channels = channels,
      provenance = provenance,
      adjacency = adjacency
    ),
    class = "cellspec"
  )
}

.cs_id_columns <- c("cell_id", "image_id", "sample_id", "subject_id",
                    "cell_id_a", "cell_id_b")

# Plain data.frame, no row names, factors as character, identifiers as
# character, specified double/integer columns coerced where lossless.
.cs_normalise_df <- function(df, component) {
  df <- as.data.frame(df, stringsAsFactors = FALSE, optional = TRUE)
  attr(df, "row.names") <- .set_row_names(nrow(df))
  class(df) <- "data.frame"
  types <- .cs_column_types(component)
  for (nm in names(df)) {
    col <- df[[nm]]
    if (is.factor(col)) {
      col <- as.character(col)
    }
    if (nm %in% .cs_id_columns && (is.numeric(col) || (is.logical(col) && all(is.na(col))))) {
      col <- .cs_format_id(col)
    }
    type <- if (nm %in% names(types)) types[[nm]] else NA_character_
    if (grepl("^boundary_distance__", nm)) {
      type <- "double"
    } else if (grepl("^region__", nm)) {
      type <- "character"
    }
    if (!is.na(type)) {
      col <- .cs_coerce_type(col, type)
    }
    df[[nm]] <- col
  }
  df
}

# Identifiers from numeric columns: whole numbers without scientific notation.
.cs_format_id <- function(x) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  if (is.numeric(x)) {
    out[ok] <- format(x[ok], scientific = FALSE, trim = TRUE, digits = 15)
  }
  out
}

.cs_coerce_type <- function(col, type) {
  if (type == "double" && (is.integer(col) || (is.logical(col) && all(is.na(col))))) {
    col <- as.double(col)
  } else if (type == "integer" && is.double(col) &&
    all(is.na(col) | (is.finite(col) & col == round(col) & abs(col) < .Machine$integer.max))) {
    col <- as.integer(col)
  } else if (type == "integer" && is.logical(col) && all(is.na(col))) {
    col <- as.integer(col)
  } else if (type == "character" && is.logical(col) && all(is.na(col))) {
    col <- as.character(col)
  }
  col
}

.cs_normalise_measurements <- function(m, n, call = rlang::caller_env()) {
  if (is.null(m)) {
    m <- matrix(numeric(0), nrow = n, ncol = 0L)
  }
  if (is.data.frame(m)) {
    is_num <- vapply(m, function(col) is.numeric(col) || (is.logical(col) && all(is.na(col))), logical(1))
    if (!all(is_num)) {
      .cs_abort(
        c("{.arg measurements} must contain numeric columns only.",
          "x" = "Non-numeric column{?s}: {.val {names(m)[!is_num]}}."),
        call = call
      )
    }
    cn <- names(m)
    m <- matrix(
      as.double(unlist(m, use.names = FALSE)),
      nrow = nrow(m),
      ncol = ncol(m),
      dimnames = list(NULL, cn)
    )
  }
  if (!is.matrix(m) || !(is.numeric(m) || is.logical(m))) {
    .cs_abort(
      c("{.arg measurements} must be a numeric matrix or data frame.",
        "x" = "Got {.obj_type_friendly {m}}."),
      call = call
    )
  }
  if (!is.double(m)) {
    storage.mode(m) <- "double"
  }
  cn <- colnames(m)
  if (is.null(cn) && ncol(m) > 0L) {
    .cs_abort(
      "{.arg measurements} must have column names equal to {.code dictionary$feature_id}.",
      call = call
    )
  }
  dimnames(m) <- list(NULL, if (ncol(m) > 0L) cn else NULL)
  bad <- !is.na(m) & !is.finite(m)
  nonfinite <- sum(bad) + sum(is.nan(m))
  if (nonfinite > 0L) {
    m[bad | is.nan(m)] <- NA_real_
  }
  attr(m, "cs_nonfinite") <- as.integer(nonfinite)
  m
}

.cs_empty_df <- function(component) {
  types <- .cs_column_types(component)
  cols <- lapply(types, function(type) vector(type, 0L))
  out <- as.data.frame(cols, stringsAsFactors = FALSE, optional = TRUE)
  names(out) <- names(types)
  out
}

.cs_now_utc <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.cs_package_version <- function() {
  as.character(utils::packageVersion("cellspecR"))
}

.cs_default_provenance <- function(provenance, adapter, n, nonfinite = 0L) {
  now <- .cs_now_utc()
  defaults <- list(
    producer = list(tool = NA_character_, version = NA_character_),
    reader = list(
      package = "cellspecR",
      version = .cs_package_version(),
      adapter = adapter,
      adapter_version = NA_character_
    ),
    created_utc = now,
    inputs = list(),
    counts = list(
      rows_read = n,
      rows_kept = n,
      na_converted = 0L,
      nonfinite_converted = 0L
    ),
    parameters = list(),
    history = list()
  )
  if (is.null(provenance)) {
    provenance <- defaults
    provenance$history <- list(.cs_history_entry(
      step = "create",
      fun = adapter,
      details = list(n_cells = n)
    ))
  } else {
    for (nm in names(defaults)) {
      if (is.null(provenance[[nm]])) {
        provenance[[nm]] <- defaults[[nm]]
      } else if (is.list(defaults[[nm]]) && length(defaults[[nm]]) > 0L && is.list(provenance[[nm]])) {
        for (sub in names(defaults[[nm]])) {
          if (is.null(provenance[[nm]][[sub]])) {
            provenance[[nm]][[sub]] <- defaults[[nm]][[sub]]
          }
        }
      }
    }
  }
  if (nonfinite > 0L) {
    prior <- provenance$counts$nonfinite_converted
    prior <- if (is.numeric(prior) && length(prior) == 1L && !is.na(prior)) prior else 0L
    provenance$counts$nonfinite_converted <- as.integer(prior + nonfinite)
  }
  provenance
}

.cs_history_entry <- function(step, fun, details = list()) {
  list(step = step, "function" = fun, time_utc = .cs_now_utc(), details = details)
}

.cs_add_history <- function(x, step, fun, details = list()) {
  x$provenance$history <- c(
    x$provenance$history,
    list(.cs_history_entry(step = step, fun = fun, details = details))
  )
  x
}

# Accessors ---------------------------------------------------------------

#' Access the components of a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Accessors return the components of a `cellspec` object. Use them instead
#' of `x$cells` so code keeps working if the internal layout changes.
#'
#' @param x A `cellspec` object.
#' @return
#' * `cs_cells()`: data frame, one row per cell.
#' * `cs_measurements()`: double matrix, cells x features, column names are
#'   feature identifiers.
#' * `cs_dictionary()`: data frame, one row per measurement column.
#' * `cs_images()`: data frame, one row per image.
#' * `cs_channels()`: data frame, one row per image and channel.
#' * `cs_provenance()`: list with `producer`, `reader`, `created_utc`,
#'   `inputs`, `counts`, `parameters` and `history`.
#' * `cs_adjacency()`: data frame of cell-cell contacts, or `NULL`.
#' @family object
#' @seealso `vignette("specification", package = "cellspecR")`
#' @name cs_accessors
#' @examples
#' x <- cs_example()
#' head(cs_cells(x))
#' dim(cs_measurements(x))
#' cs_dictionary(x)[1:3, ]
#' cs_images(x)
#' cs_channels(x)
#' names(cs_provenance(x))
#' cs_adjacency(x)
NULL

#' @rdname cs_accessors
#' @export
cs_cells <- function(x) {
  .cs_check_cellspec(x)
  x$cells
}

#' @rdname cs_accessors
#' @export
cs_measurements <- function(x) {
  .cs_check_cellspec(x)
  x$measurements
}

#' @rdname cs_accessors
#' @export
cs_dictionary <- function(x) {
  .cs_check_cellspec(x)
  x$dictionary
}

#' @rdname cs_accessors
#' @export
cs_images <- function(x) {
  .cs_check_cellspec(x)
  x$images
}

#' @rdname cs_accessors
#' @export
cs_channels <- function(x) {
  .cs_check_cellspec(x)
  x$channels
}

#' @rdname cs_accessors
#' @export
cs_provenance <- function(x) {
  .cs_check_cellspec(x)
  x$provenance
}

#' @rdname cs_accessors
#' @export
cs_adjacency <- function(x) {
  .cs_check_cellspec(x)
  x$adjacency
}

#' Select features and markers by their dictionary entries
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `cs_features()` returns the identifiers of measurement columns whose
#' dictionary entries match every supplied filter. Select features through
#' this function rather than by splitting `feature_id` strings; the identifier
#' layout is not part of the contract downstream code may parse.
#'
#' `cs_markers()` returns the markers that have at least one intensity
#' feature.
#'
#' @param x A `cellspec` object.
#' @param kind,marker,compartment,statistic Character vectors of allowed
#'   values, or `NULL` for no filter on that column.
#' @return `cs_features()`: character vector of `feature_id` values in
#'   dictionary order (length 0 when nothing matches). `cs_markers()`:
#'   character vector of marker names in order of first appearance.
#' @family object
#' @export
#' @examples
#' x <- cs_example()
#' cs_features(x, kind = "intensity", statistic = "mean")
#' cs_features(x, marker = "FOXP3")
#' cs_markers(x)
cs_features <- function(x, kind = NULL, marker = NULL, compartment = NULL,
                        statistic = NULL) {
  .cs_check_cellspec(x)
  dict <- x$dictionary
  keep <- rep(TRUE, nrow(dict))
  filters <- list(kind = kind, marker = marker, compartment = compartment,
                  statistic = statistic)
  for (nm in names(filters)) {
    value <- filters[[nm]]
    if (is.null(value)) {
      next
    }
    if (!is.character(value)) {
      .cs_abort(
        c("{.arg {nm}} must be a character vector or {.code NULL}.",
          "x" = "Got {.obj_type_friendly {value}}.")
      )
    }
    keep <- keep & !is.na(dict[[nm]]) & dict[[nm]] %in% value
  }
  dict$feature_id[keep]
}

#' @rdname cs_features
#' @export
cs_markers <- function(x) {
  .cs_check_cellspec(x)
  dict <- x$dictionary
  m <- dict$marker[dict$kind == "intensity" & !is.na(dict$marker)]
  unique(m)
}
