# S3 methods for cellspec objects.

#' Test for a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' @param x Any R object.
#' @return `TRUE` if `x` inherits from `"cellspec"`, otherwise `FALSE`. The
#'   object is not validated; use [cs_validate()] for that.
#' @family object
#' @export
#' @examples
#' is_cellspec(cs_example())
#' is_cellspec(data.frame())
is_cellspec <- function(x) {
  inherits(x, "cellspec")
}

#' Print, summarise and measure a cellspec object
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `print()` shows a compact overview that fits in 80 columns: cells, images,
#' samples, features by kind, markers, pixel size, specification version and
#' the adapter that produced the object. `summary()` returns one row per
#' image. `dim()` returns the number of cells and features.
#'
#' @param x,object A `cellspec` object (or, for the summary print method, a
#'   `cellspec_summary`).
#' @param ... Unused; for compatibility with the generics.
#' @return
#' * `print()` returns `x` invisibly.
#' * `summary()` returns a data frame of class `cellspec_summary` with one row
#'   per image and the columns `image_id`, `sample_id` (character), `n_cells`,
#'   `n_markers`, `n_features` (integer; markers and features with at least
#'   one non-missing value in that image), `pixel_size`, `x_min`, `x_max`,
#'   `y_min`, `y_max` (double, micrometres) and `na_fraction` (double,
#'   fraction of missing measurement values in that image).
#' * `dim()` returns an integer vector `c(cells, features)`.
#' @family methods
#' @name cellspec-methods
#' @examples
#' x <- cs_example()
#' x
#' summary(x)
#' dim(x)
NULL

#' @rdname cellspec-methods
#' @export
print.cellspec <- function(x, ...) {
  cells <- x$cells
  dict <- x$dictionary
  images <- x$images
  n_img <- nrow(images)
  n_smp <- length(unique(images$sample_id))
  kinds <- table(factor(dict$kind, levels = .cs_vocab_values("kind")))
  markers <- cs_markers(x)
  prov <- x$provenance

  lines <- c(
    paste0("<cellspec> spec ", x$spec_version),
    .cs_line("cells", paste0(
      .cs_fmt_int(nrow(cells)), " in ", n_img, " image", if (n_img != 1L) "s",
      " (", n_smp, " sample", if (n_smp != 1L) "s", ")"
    )),
    .cs_line("features", paste0(
      .cs_fmt_int(nrow(dict)),
      if (nrow(dict) > 0L) paste0(": ", paste0(kinds[kinds > 0], " ", names(kinds)[kinds > 0], collapse = ", ")) else ""
    )),
    .cs_line("markers", if (length(markers) == 0L) "none" else paste0(
      length(markers), ": ", paste(markers, collapse = ", ")
    )),
    .cs_line("pixel", .cs_fmt_pixel(images$pixel_size)),
    .cs_line("adjacency", if (is.null(x$adjacency)) "none" else paste0(.cs_fmt_int(nrow(x$adjacency)), " contacts")),
    .cs_line("source", .cs_fmt_source(prov))
  )
  cat(.cs_truncate(lines, 80L), sep = "\n")
  invisible(x)
}

.cs_line <- function(label, value) {
  paste0("  ", formatC(label, width = -10L), value)
}

.cs_truncate <- function(lines, width) {
  long <- nchar(lines, type = "width") > width
  lines[long] <- paste0(substr(lines[long], 1L, width - 3L), "...")
  lines
}

.cs_fmt_int <- function(n) {
  formatC(n, format = "d", big.mark = ",")
}

.cs_fmt_pixel <- function(ps) {
  ps <- unique(ps[!is.na(ps)])
  if (length(ps) == 0L) {
    return("unknown")
  }
  if (length(ps) == 1L) {
    return(paste0(format(ps, digits = 6), " um/px"))
  }
  paste0(format(min(ps), digits = 6), "-", format(max(ps), digits = 6),
         " um/px (", length(ps), " values)")
}

.cs_fmt_source <- function(prov) {
  reader <- prov$reader
  adapter <- if (is.null(reader$adapter) || is.na(reader$adapter)) "unknown" else reader$adapter
  av <- reader$adapter_version
  out <- adapter
  if (!is.null(av) && length(av) == 1L && !is.na(av)) {
    out <- paste0(out, " ", av)
  }
  tool <- prov$producer$tool
  if (!is.null(tool) && length(tool) == 1L && !is.na(tool)) {
    tv <- prov$producer$version
    out <- paste0(out, " (", tool,
                  if (!is.null(tv) && length(tv) == 1L && !is.na(tv)) paste0(" ", tv) else "",
                  ")")
  }
  out
}

#' @rdname cellspec-methods
#' @export
summary.cellspec <- function(object, ...) {
  x <- object
  cells <- x$cells
  m <- x$measurements
  dict <- x$dictionary
  images <- x$images
  int_cols <- dict$kind == "intensity"
  rows <- split(seq_len(nrow(cells)), factor(cells$image_id, levels = images$image_id))
  per_image <- lapply(images$image_id, function(img) {
    r <- rows[[img]]
    if (is.null(r)) r <- integer()
    sub <- m[r, , drop = FALSE]
    has_value <- if (length(r) > 0L) colSums(!is.na(sub)) > 0L else rep(FALSE, ncol(m))
    data.frame(
      n_cells = length(r),
      n_markers = length(unique(dict$marker[int_cols & has_value])),
      n_features = sum(has_value),
      x_min = if (length(r) > 0L) min(cells$x[r]) else NA_real_,
      x_max = if (length(r) > 0L) max(cells$x[r]) else NA_real_,
      y_min = if (length(r) > 0L) min(cells$y[r]) else NA_real_,
      y_max = if (length(r) > 0L) max(cells$y[r]) else NA_real_,
      na_fraction = if (length(sub) > 0L) mean(is.na(sub)) else NA_real_
    )
  })
  stats_df <- do.call(rbind, per_image)
  out <- data.frame(
    image_id = images$image_id,
    sample_id = images$sample_id,
    n_cells = as.integer(stats_df$n_cells),
    n_markers = as.integer(stats_df$n_markers),
    n_features = as.integer(stats_df$n_features),
    pixel_size = images$pixel_size,
    x_min = stats_df$x_min,
    x_max = stats_df$x_max,
    y_min = stats_df$y_min,
    y_max = stats_df$y_max,
    na_fraction = stats_df$na_fraction,
    stringsAsFactors = FALSE
  )
  class(out) <- c("cellspec_summary", "data.frame")
  out
}

#' @rdname cellspec-methods
#' @export
print.cellspec_summary <- function(x, ...) {
  n <- nrow(x)
  cat("<cellspec summary> ", n, " image", if (n != 1L) "s", ", ",
      .cs_fmt_int(sum(x$n_cells)), " cells\n", sep = "")
  df <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  for (nm in c("pixel_size", "x_min", "x_max", "y_min", "y_max")) {
    df[[nm]] <- signif(df[[nm]], 5)
  }
  df$na_fraction <- round(df$na_fraction, 4)
  print(df, row.names = FALSE)
  invisible(x)
}

#' @rdname cellspec-methods
#' @export
dim.cellspec <- function(x) {
  c(nrow(x$cells), ncol(x$measurements))
}

#' Subset a cellspec object by cells and features
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `x[i, j]` keeps the cells selected by `i` and the features selected by `j`.
#' All components stay aligned: `cells` and `measurements` rows are subset
#' together, dictionary rows follow the kept features, and adjacency contacts
#' whose cells were removed are dropped. `images` and `channels` are kept
#' unchanged.
#'
#' @param x A `cellspec` object.
#' @param i Cells to keep: a logical vector with one value per cell, or
#'   positive or negative integer positions. Missing means all cells.
#' @param j Features to keep: a character vector of feature identifiers, a
#'   logical vector with one value per feature, or integer positions. Missing
#'   means all features.
#' @param ... Not used; must be empty.
#' @param drop Not used; subsetting always returns a `cellspec` object.
#' @return A `cellspec` object.
#' @family methods
#' @export
#' @examples
#' x <- cs_example()
#' dim(x)
#' big <- x[cs_cells(x)$area > 60, ]
#' dim(big)
#' means <- x[, cs_features(x, statistic = "mean")]
#' dim(means)
`[.cellspec` <- function(x, i, j, ..., drop = FALSE) {
  n_index <- nargs() - as.integer(!missing(drop))
  if (n_index < 3L) {
    .cs_abort(c(
      "Subset a {.cls cellspec} object with two indices.",
      "i" = "Use {.code x[i, ]} for cells and {.code x[, j]} for features."
    ))
  }
  rlang::check_dots_empty()
  n <- nrow(x$cells)
  rows <- if (missing(i)) seq_len(n) else .cs_resolve_index(i, n, "i", "cells")
  p <- ncol(x$measurements)
  cols <- if (missing(j)) seq_len(p) else .cs_resolve_index(j, p, "j", "features", names = x$dictionary$feature_id)

  cells <- x$cells[rows, , drop = FALSE]
  attr(cells, "row.names") <- .set_row_names(nrow(cells))
  m <- x$measurements[rows, cols, drop = FALSE]
  dict <- x$dictionary[cols, , drop = FALSE]
  attr(dict, "row.names") <- .set_row_names(nrow(dict))

  adj <- x$adjacency
  if (!is.null(adj)) {
    keys <- .cs_key(cells$image_id, cells$cell_id)
    keep <- .cs_key(adj$image_id, adj$cell_id_a) %in% keys &
      .cs_key(adj$image_id, adj$cell_id_b) %in% keys
    adj <- adj[keep, , drop = FALSE]
    attr(adj, "row.names") <- .set_row_names(nrow(adj))
  }

  x$cells <- cells
  x$measurements <- m
  x$dictionary <- dict
  x$adjacency <- adj
  x
}

.cs_resolve_index <- function(idx, n, arg, what, names = NULL, call = rlang::caller_env()) {
  if (is.logical(idx)) {
    if (length(idx) != n || anyNA(idx)) {
      .cs_abort(c(
        "Logical {.arg {arg}} must have one non-missing value per {what} ({n}).",
        "x" = "Got length {length(idx)}{if (anyNA(idx)) ' with missing values' else ''}."
      ), call = call)
    }
    return(which(idx))
  }
  if (is.character(idx)) {
    if (is.null(names)) {
      .cs_abort(c(
        "{.arg {arg}} cannot be a character vector when selecting {what}.",
        "i" = "Select cells with a logical vector, e.g. {.code x[cs_cells(x)$image_id == \"img1\", ]}."
      ), call = call)
    }
    pos <- match(idx, names)
    if (anyNA(pos)) {
      .cs_abort(c(
        "{.arg {arg}} must name existing {what}.",
        "x" = "Unknown: {.val {idx[is.na(pos)]}}."
      ), call = call)
    }
    idx <- pos
  }
  if (!is.numeric(idx) || anyNA(idx) || any(idx != round(idx))) {
    .cs_abort(c(
      "{.arg {arg}} must be logical, whole-number positions or (for features) identifiers.",
      "x" = "Got {.obj_type_friendly {idx}}."
    ), call = call)
  }
  if (length(idx) > 0L && all(idx <= 0)) {
    if (any(idx < -n)) {
      .cs_abort("Negative {.arg {arg}} is out of range (there are {n} {what}).", call = call)
    }
    idx <- setdiff(seq_len(n), -idx)
  } else if (any(idx < 0)) {
    .cs_abort("{.arg {arg}} cannot mix positive and negative positions.", call = call)
  } else {
    idx <- idx[idx != 0]
    if (any(idx > n)) {
      .cs_abort("{.arg {arg}} selects positions beyond the {n} {what}.", call = call)
    }
  }
  if (anyDuplicated(idx)) {
    .cs_abort(c(
      "{.arg {arg}} selects some {what} more than once.",
      "i" = "Duplicated {what} would break the uniqueness of identifiers."
    ), call = call)
  }
  as.integer(idx)
}

#' Convert a cellspec object to a data frame
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Combines the `cells` columns with selected measurement columns into one
#' wide data frame, for example to hand a table to modelling code.
#' Measurement columns are named by their feature identifiers.
#'
#' @param x A `cellspec` object.
#' @param row.names,optional Ignored; present for compatibility with the
#'   generic.
#' @param features Character vector of feature identifiers to include
#'   (default: all features).
#' @param ... Unused.
#' @return A `data.frame` with one row per cell: the `cells` columns followed
#'   by one double column per selected feature. `as_tibble()` returns the
#'   same content as a tibble (requires the tibble package).
#' @family methods
#' @export
#' @examples
#' x <- cs_example()
#' df <- as.data.frame(x, features = cs_features(x, statistic = "mean"))
#' head(df)
as.data.frame.cellspec <- function( # nolint: object_name_linter.
    x, row.names = NULL, optional = FALSE, ..., features = NULL) {
  if (is.null(features)) {
    features <- x$dictionary$feature_id
  }
  if (!is.character(features) || anyNA(match(features, x$dictionary$feature_id))) {
    .cs_abort(c(
      "{.arg features} must name existing features.",
      "x" = "Unknown: {.val {setdiff(features, x$dictionary$feature_id)}}."
    ))
  }
  clash <- intersect(features, names(x$cells))
  if (length(clash) > 0L) {
    .cs_abort("Feature identifiers clash with {.field cells} column names: {.val {clash}}.")
  }
  meas <- as.data.frame(x$measurements[, features, drop = FALSE], optional = TRUE)
  names(meas) <- features
  out <- cbind(x$cells, meas)
  attr(out, "row.names") <- .set_row_names(nrow(out))
  out
}

#' @rdname as.data.frame.cellspec
#' @exportS3Method tibble::as_tibble
as_tibble.cellspec <- function(x, ..., features = NULL) {
  rlang::check_installed("tibble")
  tibble::as_tibble(as.data.frame.cellspec(x, features = features))
}
