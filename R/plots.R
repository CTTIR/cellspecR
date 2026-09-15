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

.cs_plot_signal_long <- function(x, marker = NULL, policy = NULL, call) {
  dict <- x$dictionary[x$dictionary$kind == "intensity", , drop = FALSE]
  if (!is.null(marker)) {
    .cs_check_string(marker, arg = "marker", call = call)
    dict <- dict[dict$marker == marker, , drop = FALSE]
  }
  if (nrow(dict) == 0L) {
    .cs_abort("No intensity features match {.arg marker}.", class = "cellspec_error_invalid", call = call)
  }
  rows <- rep(seq_len(nrow(x$cells)), times = nrow(dict))
  feature <- rep(dict$feature_id, each = nrow(x$cells))
  dictionary_rows <- dict[match(feature, dict$feature_id), , drop = FALSE]
  result <- data.frame(
    value = as.vector(x$measurements[, feature, drop = FALSE]),
    image_id = x$cells$image_id[rows],
    marker = dictionary_rows$marker,
    compartment = dictionary_rows$compartment,
    statistic = dictionary_rows$statistic,
    stringsAsFactors = FALSE
  )
  if (!is.null(policy)) {
    .cs_validate_signal_policy(policy, call = call)
    selected <- cs_signal_matrix(x, policy)$signal
    selected_marker <- if (is.null(marker)) policy$marker[[1L]] else marker
    if (selected_marker %in% colnames(selected)) {
      result <- data.frame(
        value = selected[, selected_marker],
        image_id = x$cells$image_id,
        marker = selected_marker,
        compartment = "selected",
        statistic = "selected",
        stringsAsFactors = FALSE
      )
    }
  }
  result[is.finite(result$value) & !is.na(result$value), , drop = FALSE]
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
    x = cells$x[keep], y = -cells$y[keep], colour = colour[keep],
    stringsAsFactors = FALSE
  )
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$x, y = .data$y, colour = .data$colour)) +
    ggplot2::geom_point(size = 0.7, alpha = 0.75) +
    ggplot2::coord_fixed() +
    ggplot2::labs(x = "x (\u00b5m)", y = "-y (\u00b5m; image origin at top)", colour = colour_by) +
    ggplot2::theme_minimal()
  if (is.numeric(data$colour)) {
    p + ggplot2::scale_colour_viridis_c(na.value = "grey70")
  } else {
    p + ggplot2::scale_colour_viridis_d(na.value = "grey70")
  }
}

.cs_plot_marker <- function(x, marker, policy, call) {
  data <- .cs_plot_signal_long(x, marker = marker, policy = policy, call = call)
  ggplot2::ggplot(data, ggplot2::aes(x = .data$compartment, y = .data$value, fill = .data$compartment)) +
    ggplot2::geom_violin(scale = "width", na.rm = TRUE) +
    ggplot2::geom_boxplot(width = 0.12, outlier.shape = NA, na.rm = TRUE) +
    ggplot2::facet_wrap(~image_id) +
    ggplot2::scale_fill_viridis_d() +
    ggplot2::labs(x = NULL, y = "Signal (raw units)") +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "none")
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
    ggplot2::labs(x = "Cell area (\u00b5m^2)", y = "Cells", fill = "Image") +
    ggplot2::theme_minimal()
}

#' Plot cellspec quality-control views
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Draws a centroid map, marker distribution, feature-support heatmap, cell
#' area distribution, or a four-panel overview. Large objects are subsampled
#' deterministically for plotting.
#'
#' @param x A `cellspec` object.
#' @param type Plot type: `"overview"`, `"map"`, `"marker"`, `"support"` or
#'   `"area"`.
#' @param colour_by A cells or measurement column used by the map.
#' @param marker Marker used by the marker plot.
#' @param policy Optional signal policy for the marker plot.
#' @param max_points Maximum number of cells used by a plot.
#' @param seed Seed used for deterministic subsampling.
#' @param ... Reserved for future plot-specific parameters.
#' @return A `ggplot` object, or a patchwork object for `type = "overview"`.
#' @family methods
#' @export
#' @examples
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot(cs_example(), type = "map")
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
  if (type == "marker") return(.cs_plot_marker(x, marker, policy, call))
  if (type == "support") return(.cs_plot_support(x, call))
  if (type == "area") return(.cs_plot_area(x, call))
  .cs_plot_require("patchwork", call = call)
  patchwork::wrap_plots(
    .cs_plot_map(x, colour_by, max_points, seed, call),
    .cs_plot_support(x, call),
    .cs_plot_area(x, call),
    .cs_plot_marker(x, marker, policy, call),
    ncol = 2
  )
}
