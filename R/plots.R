# Quality-control plots for cellspec objects.

utils::globalVariables(".data")

.cs_plot_require <- function(package, call = rlang::caller_env()) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .cs_abort(
      c("Plotting needs {.pkg {package}}.", "i" = "Install {.pkg {package}} to draw this plot."),
      class = "cellspec_error_format", call = call
    )
  }
  invisible(TRUE)
}

.cs_plot_subsample <- function(x, max_points, seed, call) {
  .cs_check_count(max_points, min = 1L, arg = "max_points", call = call)
  if (nrow(x) <= max_points) return(seq_len(nrow(x)))
  .cs_with_seed(seed, sample.int(nrow(x), max_points))
}

# Long table of the intensity values of one marker: one row per cell and
# source (compartment and statistic). Without `marker` the first marker of the
# policy, or else of the dictionary, is used. `rows` restricts the cells.
.cs_plot_signal_long <- function(x, marker = NULL, policy = NULL, rows = NULL, call) {
  dict <- x$dictionary[x$dictionary$kind %in% "intensity", , drop = FALSE]
  if (!is.null(policy)) {
    .cs_validate_signal_policy(policy, call = call)
  }
  if (is.null(marker)) {
    marker <- if (is.null(policy)) dict$marker[!is.na(dict$marker)][1L] else policy$marker[[1L]]
  } else {
    .cs_check_string(marker, arg = "marker", call = call)
  }
  dict <- dict[dict$marker %in% marker, , drop = FALSE]
  if (nrow(dict) == 0L) {
    .cs_abort("No intensity features match {.arg marker}.", class = "cellspec_error_invalid", call = call)
  }
  if (is.null(rows)) {
    rows <- seq_len(nrow(x$cells))
  }
  n <- length(rows)
  result <- data.frame(
    value = as.vector(x$measurements[rows, dict$feature_id, drop = FALSE]),
    image_id = rep(x$cells$image_id[rows], times = nrow(dict)),
    marker = rep(dict$marker, each = n),
    compartment = rep(dict$compartment, each = n),
    statistic = rep(dict$statistic, each = n),
    stringsAsFactors = FALSE
  )
  if (!is.null(policy) && marker %in% policy$marker) {
    selected <- cs_signal_matrix(x, policy)$signal
    result <- data.frame(
      value = unname(selected[rows, marker]),
      image_id = x$cells$image_id[rows],
      marker = rep(marker, n),
      compartment = rep("selected", n),
      statistic = rep("selected", n),
      stringsAsFactors = FALSE
    )
  }
  result[is.finite(result$value), , drop = FALSE]
}

.cs_plot_map <- function(x, colour_by, max_points, seed, call) {
  cells <- x$cells
  if (is.null(colour_by)) {
    colour_by <- "image_id"
  } else {
    .cs_check_string(colour_by, arg = "colour_by", call = call)
  }
  if (colour_by %in% names(cells)) {
    colour <- cells[[colour_by]]
  } else if (colour_by %in% colnames(x$measurements)) {
    colour <- x$measurements[, colour_by]
  } else {
    .cs_abort(
      c("{.arg colour_by} is not a cells or measurement column.", "x" = "Unknown name {.val {colour_by}}."),
      class = "cellspec_error_invalid", call = call
    )
  }
  keep <- .cs_plot_subsample(cells, max_points, seed, call)
  data <- data.frame(
    x = cells$x[keep], y = cells$y[keep], colour = colour[keep],
    stringsAsFactors = FALSE
  )
  # Image coordinates start at the top left, so the y axis runs downwards.
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$x, y = .data$y, colour = .data$colour)) +
    ggplot2::geom_point(size = 0.7, alpha = 0.75) +
    ggplot2::scale_y_reverse() +
    ggplot2::coord_fixed() +
    ggplot2::labs(x = "x (\u00b5m)", y = "y (\u00b5m)", colour = colour_by) +
    ggplot2::theme_minimal()
  if (is.numeric(data$colour)) {
    p + ggplot2::scale_colour_viridis_c(na.value = "grey70")
  } else {
    p + ggplot2::scale_colour_viridis_d(na.value = "grey70")
  }
}

# Violins of one marker per source (compartment and statistic), one panel per
# image. With `empty_ok`, an object without finite values of the marker gives
# `NULL` instead of an error, so the overview can leave the panel out.
.cs_plot_marker <- function(x, marker, policy, max_points, seed, call, empty_ok = FALSE) {
  keep <- .cs_plot_subsample(x$cells, max_points, seed, call)
  data <- .cs_plot_signal_long(x, marker = marker, policy = policy, rows = keep, call = call)
  if (nrow(data) == 0L) {
    if (empty_ok) {
      return(NULL)
    }
    .cs_abort(
      "There are no finite intensity values to plot for {.arg marker}.",
      class = "cellspec_error_invalid", call = call
    )
  }
  data$source <- ifelse(
    data$compartment == "selected", "selected",
    paste(data$compartment, data$statistic, sep = ":")
  )
  # Statistics on the axis and compartments side by side keep the labels
  # short enough for the overview panel.
  dodge <- ggplot2::position_dodge(width = 0.85)
  ggplot2::ggplot(data, ggplot2::aes(x = .data$statistic, y = .data$value, fill = .data$compartment)) +
    ggplot2::geom_violin(scale = "width", position = dodge, alpha = 0.85, na.rm = TRUE) +
    ggplot2::geom_boxplot(
      ggplot2::aes(group = .data$source),
      width = 0.12, position = dodge, fill = "white", outlier.shape = NA, na.rm = TRUE
    ) +
    ggplot2::facet_wrap(~image_id) +
    ggplot2::scale_fill_viridis_d(begin = 0.25, end = 0.9) +
    ggplot2::labs(
      title = data$marker[[1L]], x = NULL, y = "Signal (raw units)",
      fill = "Compartment"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = if (length(unique(data$compartment)) > 1L) "bottom" else "none"
    )
}

.cs_plot_support <- function(x, call) {
  support <- cs_feature_support(x)
  support$label <- paste(support$marker, support$compartment, support$statistic, sep = ":")
  ggplot2::ggplot(support, ggplot2::aes(x = .data$image_id, y = .data$label, fill = .data$fraction_zero)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_viridis_c(limits = c(0, 1), na.value = "grey85") +
    ggplot2::labs(x = NULL, y = NULL, fill = "Fraction zero") +
    ggplot2::theme_minimal() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 7))
}

.cs_plot_area <- function(x, call) {
  if (!"area" %in% names(x$cells)) {
    .cs_abort("The cells table has no {.field area} column.", class = "cellspec_error_invalid", call = call)
  }
  data <- x$cells[is.finite(x$cells$area) & !is.na(x$cells$area), , drop = FALSE]
  ggplot2::ggplot(data, ggplot2::aes(x = .data$area, fill = .data$image_id)) +
    ggplot2::geom_histogram(bins = 30, alpha = 0.75, position = "identity") +
    ggplot2::scale_fill_viridis_d() +
    ggplot2::labs(x = "Cell area (\u00b5m\u00b2)", y = "Cells", fill = "Image") +
    ggplot2::theme_minimal()
}

#' Plot cellspec quality-control views
#'
#' @description
#' Draws a centroid map, marker distribution, feature-support heatmap, cell
#' area distribution, or an overview of up to four panels. The overview leaves
#' out the area panel when the cells table has no `area` column and the marker
#' panel when there are no intensity features or no finite values to draw.
#'
#' The map follows the image frame: the origin is at the top left and `y`
#' increases downwards. The marker plot shows one marker: a violin per
#' intensity source (statistic on the axis, compartments side by side) and
#' one panel per image.
#' Maps and marker plots of large objects use a deterministic subsample of
#' `max_points` cells; the support heatmap and the area histogram always use
#' every cell.
#'
#' @param x A `cellspec` object.
#' @param type Plot type: `"overview"`, `"map"`, `"marker"`, `"support"` or
#'   `"area"`.
#' @param colour_by A cells or measurement column used by the map. Defaults
#'   to `image_id`.
#' @param marker Marker shown by the marker plot. Defaults to the first
#'   marker of `policy` or, without a policy, the first marker returned by
#'   [cs_markers()].
#' @param policy Optional signal policy for the marker plot. When it covers
#'   `marker`, the plot shows the signal selected by [cs_signal_matrix()]
#'   instead of the individual sources.
#' @param max_points Maximum number of cells drawn by the map and the marker
#'   plot.
#' @param seed Seed used for deterministic subsampling. The random number
#'   generator state of the session is left untouched.
#' @param ... Reserved for future plot-specific parameters.
#' @return A `ggplot` object, or a patchwork object for `type = "overview"`.
#' @family methods
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   x <- cs_example()
#'   plot(x, type = "map")
#'   plot(x, type = "marker", marker = "CD3e")
#' }
plot.cellspec <- function(x, type = c("overview", "map", "marker", "support", "area"),
                          colour_by = NULL, marker = NULL, policy = NULL,
                          max_points = 50000L, seed = 1L, ...) {
  call <- rlang::caller_env()
  .cs_check_cellspec(x, call = call)
  .cs_plot_require("ggplot2", call = call)
  type <- rlang::arg_match(type)
  .cs_check_count(seed, min = 0L, arg = "seed", call = call)
  if (type == "map") return(.cs_plot_map(x, colour_by, max_points, seed, call))
  if (type == "marker") return(.cs_plot_marker(x, marker, policy, max_points, seed, call))
  if (type == "support") return(.cs_plot_support(x, call))
  if (type == "area") return(.cs_plot_area(x, call))
  .cs_plot_require("patchwork", call = call)
  panels <- list(
    .cs_plot_map(x, colour_by, max_points, seed, call),
    .cs_plot_support(x, call)
  )
  if ("area" %in% names(x$cells)) {
    panels <- c(panels, list(.cs_plot_area(x, call)))
  }
  if (any(x$dictionary$kind %in% "intensity")) {
    marker_panel <- .cs_plot_marker(x, marker, policy, max_points, seed, call, empty_ok = TRUE)
    if (!is.null(marker_panel)) {
      panels <- c(panels, list(marker_panel))
    }
  }
  patchwork::wrap_plots(panels, ncol = 2)
}
