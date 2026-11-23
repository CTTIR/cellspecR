# Quality-control plots for cellspec objects.

utils::globalVariables(".data")

.cs_plot_require <- function(package, minimum = NULL, call = rlang::caller_env()) {
  if (!requireNamespace(package, quietly = TRUE)) {
    .cs_abort(
      c("Plotting needs {.pkg {package}}.", "i" = "Install {.pkg {package}} to draw this plot."),
      class = "cellspec_error_format", call = call
    )
  }
  # The version that DESCRIPTION declares: older ones lack arguments used here.
  if (!is.null(minimum) && utils::packageVersion(package) < minimum) {
    installed <- as.character(utils::packageVersion(package))
    .cs_abort(
      c(
        "Plotting needs {.pkg {package}} {minimum} or later.",
        "x" = "Version {installed} is installed."
      ),
      class = "cellspec_error_format", call = call
    )
  }
  invisible(TRUE)
}

# Colour of marks that carry no colour scale: the dark blue of the viridis
# scale, readable on a white and on a light grey background.
.cs_plot_colour <- "#3B528B"

# Images in the order of the images table, so that panels and axes do not
# sort `img10` before `img2`.
.cs_plot_image_levels <- function(x, image_id) {
  levels <- unique(c(x$images$image_id, image_id))
  levels[levels %in% image_id]
}

# One panel per image, in the order of `levels`, on common axes. Several
# panels share the width, so they get fewer axis breaks, drop tick labels
# that would still overprint, and shrink strip labels that would not fit
# their panel. `compact` is set by the overview, where a view has half the
# width. With more than `max_panels` images the panels could not be read at
# the default device size, so the images are pooled in one panel and the
# subtitle says so. Without data there is nothing to facet by.
.cs_plot_image_panels <- function(p, image_id, levels, max_panels, compact = FALSE,
                                  y_scale = ggplot2::scale_y_continuous,
                                  thin_x = TRUE) {
  n <- length(levels)
  if (length(image_id) == 0L || n <= 1L) {
    return(p + y_scale())
  }
  if (n > max_panels) {
    return(p + y_scale() + ggplot2::labs(subtitle = sprintf("%d images pooled in one panel", n)))
  }
  breaks <- if (n > 4L) 3 else 4
  guide <- ggplot2::guide_axis(check.overlap = TRUE)
  if (thin_x) {
    p <- p + ggplot2::scale_x_continuous(n.breaks = breaks, guide = guide)
  }
  # About 0.55 of the font size per character; 6 inches of a 7 inch device
  # are left for the panels, half of that in the overview.
  columns <- ggplot2::wrap_dims(n)[[2L]]
  width <- if (compact) 3 else 6
  strip_size <- width * 72 / (0.55 * columns * max(nchar(levels), 1L))
  p +
    y_scale(n.breaks = breaks, guide = guide) +
    ggplot2::facet_wrap(ggplot2::vars(image_id = factor(.data$image_id, levels = levels))) +
    ggplot2::theme(
      strip.text = ggplot2::element_text(size = min(8.8, max(5, strip_size))),
      # Room between the last tick label of a panel and the first of the next.
      panel.spacing.x = ggplot2::unit(1, "lines")
    )
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
  result <- if (!is.null(policy) && marker %in% policy$marker) {
    selected <- cs_signal_matrix(x, policy)$signal
    data.frame(
      value = unname(selected[rows, marker]),
      image_id = x$cells$image_id[rows],
      marker = rep(marker, n),
      compartment = rep("selected", n),
      statistic = rep("selected", n),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      value = as.vector(x$measurements[rows, dict$feature_id, drop = FALSE]),
      image_id = rep(x$cells$image_id[rows], times = nrow(dict)),
      marker = rep(dict$marker, each = n),
      compartment = rep(dict$compartment, each = n),
      statistic = rep(dict$statistic, each = n),
      stringsAsFactors = FALSE
    )
  }
  result[is.finite(result$value), , drop = FALSE]
}

.cs_plot_map <- function(x, colour_by, max_points, seed, call, max_panels = 12L, compact = FALSE) {
  cells <- x$cells
  if (is.null(colour_by)) {
    colour <- NULL
  } else {
    .cs_check_string(colour_by, arg = "colour_by", call = call)
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
  }
  keep <- .cs_plot_subsample(cells, max_points, seed, call)
  data <- data.frame(
    x = cells$x[keep], y = cells$y[keep], image_id = cells$image_id[keep],
    stringsAsFactors = FALSE
  )
  if (!is.null(colour)) {
    data$colour <- colour[keep]
  }
  # Image coordinates start at the top left, so the y axis runs downwards.
  # Overlaid images hide each other, so each one gets its own panel.
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$x, y = .data$y)) +
    ggplot2::coord_fixed() +
    ggplot2::labs(x = "x (\u00b5m)", y = "y (\u00b5m)") +
    ggplot2::theme_minimal()
  p <- .cs_plot_image_panels(
    p, data$image_id, .cs_plot_image_levels(x, data$image_id), max_panels, compact,
    y_scale = ggplot2::scale_y_reverse
  )
  if (is.null(colour)) {
    return(p + ggplot2::geom_point(size = 0.7, alpha = 0.75, colour = .cs_plot_colour))
  }
  p <- p +
    ggplot2::geom_point(ggplot2::aes(colour = .data$colour), size = 0.7, alpha = 0.75) +
    ggplot2::labs(colour = colour_by)
  if (is.numeric(data$colour)) {
    p + ggplot2::scale_colour_viridis_c(na.value = "grey70")
  } else {
    # The scale stops before the yellow end, which is hard to see on white.
    p +
      ggplot2::scale_colour_viridis_d(end = 0.9, na.value = "grey70") +
      ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(size = 2.5, alpha = 1)))
  }
}

# Violins of one marker per source (compartment and statistic), one panel per
# image. With `empty_ok`, an object without finite values of the marker gives
# `NULL` instead of an error, so the overview can leave the panel out.
.cs_plot_marker <- function(x, marker, policy, max_points, seed, call, empty_ok = FALSE,
                            max_panels = 12L, compact = FALSE) {
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
  # A density needs two values: an image and source with a single cell, as
  # can remain after subsampling, is drawn as a point.
  data$single <- stats::ave(
    data$value, data$image_id, data$source, FUN = length
  ) < 2
  # Statistics on the axis and compartments side by side keep the labels
  # short enough for the overview panel.
  dodge <- ggplot2::position_dodge(width = 0.85)
  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data$statistic, y = .data$value, fill = .data$compartment)
  ) +
    ggplot2::geom_violin(
      data = data[!data$single, , drop = FALSE],
      scale = "width", width = 0.9, position = dodge, alpha = 0.85, na.rm = TRUE
    ) +
    ggplot2::geom_boxplot(
      ggplot2::aes(group = .data$source),
      data = data[!data$single, , drop = FALSE],
      width = 0.12, position = dodge, fill = "white", outlier.shape = NA, na.rm = TRUE
    ) +
    ggplot2::geom_point(
      ggplot2::aes(group = .data$source),
      data = data[data$single, , drop = FALSE],
      position = dodge, shape = 21, size = 2, na.rm = TRUE, show.legend = FALSE
    ) +
    # Two label rows keep neighbouring statistics apart in narrow panels.
    ggplot2::guides(x = ggplot2::guide_axis(n.dodge = 2)) +
    ggplot2::scale_fill_viridis_d(begin = 0.25, end = 0.9) +
    ggplot2::labs(
      title = data$marker[[1L]], x = NULL, y = "Signal (raw units)",
      fill = "Compartment"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      legend.position = if (length(unique(data$compartment)) > 1L) "bottom" else "none"
    )
  .cs_plot_image_panels(
    p, data$image_id, .cs_plot_image_levels(x, data$image_id), max_panels, compact,
    thin_x = FALSE
  )
}

# `compact` is set by the overview, where the heatmap has half the height:
# long feature lists then get smaller labels.
.cs_plot_support <- function(x, call, compact = FALSE) {
  support <- cs_feature_support(x)
  support$label <- paste(support$marker, support$compartment, support$statistic, sep = ":")
  # White borders keep the tiles apart when neighbours have the same value;
  # with very many tiles they would hide the fill.
  border <- if (nrow(support) <= 2000L) "white" else NA
  label_size <- if (compact && length(unique(support$label)) > 24L) 5 else 7
  ggplot2::ggplot(support, ggplot2::aes(x = .data$image_id, y = .data$label, fill = .data$fraction_zero)) +
    ggplot2::geom_tile(colour = border, linewidth = 0.25) +
    ggplot2::scale_fill_viridis_c(limits = c(0, 1), na.value = "grey85") +
    # Features read from top to bottom; labels that would overprint are left out.
    ggplot2::scale_y_discrete(limits = rev, guide = ggplot2::guide_axis(check.overlap = TRUE)) +
    ggplot2::scale_x_discrete(
      limits = if (nrow(support) > 0L) .cs_plot_image_levels(x, support$image_id),
      guide = ggplot2::guide_axis(check.overlap = TRUE)
    ) +
    ggplot2::guides(fill = ggplot2::guide_colourbar(title.position = "top")) +
    ggplot2::labs(x = NULL, y = NULL, fill = "Fraction zero") +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.y = ggplot2::element_text(size = label_size),
      panel.grid = ggplot2::element_blank()
    )
}

.cs_plot_area <- function(x, call, max_panels = 12L, compact = FALSE) {
  if (!"area" %in% names(x$cells)) {
    .cs_abort("The cells table has no {.field area} column.", class = "cellspec_error_invalid", call = call)
  }
  data <- x$cells[is.finite(x$cells$area) & !is.na(x$cells$area), , drop = FALSE]
  # One panel per image: overlaid histograms hide each other.
  p <- ggplot2::ggplot(data, ggplot2::aes(x = .data$area)) +
    ggplot2::geom_histogram(bins = 30, fill = .cs_plot_colour, colour = "white", linewidth = 0.2) +
    ggplot2::labs(x = "Cell area (\u00b5m\u00b2)", y = "Cells") +
    ggplot2::theme_minimal()
  .cs_plot_image_panels(
    p, data$image_id, .cs_plot_image_levels(x, data$image_id), max_panels, compact
  )
}

#' Plot cellspec quality-control views
#'
#' @description
#' Draws a centroid map, marker distribution, feature-support heatmap, cell
#' area distribution, or an overview of up to four panels with their legends
#' below. The overview leaves out the area panel when the cells table has no
#' `area` column and the marker panel when there are no intensity features or
#' no finite values to draw.
#'
#' The map follows the image frame: the origin is at the top left and `y`
#' increases downwards. The map, the marker plot and the area histogram draw
#' one panel per image, because overlaid images hide each other. The panels
#' follow the order of the images table and share one common axis range, so an
#' image with a different extent or offset fills only part of its panel. With
#' more than `max_panels` images the panels would be too small to read: the
#' images are then pooled in one panel and the subtitle says so. The overview
#' gives each view half the width and pools above half that number. The
#' marker plot shows one marker: a violin
#' per intensity source (statistic on the axis, compartments side by side).
#' The support heatmap lists the features from top to bottom and leaves out
#' axis labels that would overprint their neighbours in a small panel.
#' Maps and marker plots of large objects use a deterministic subsample of
#' `max_points` cells; the support heatmap and the area histogram always use
#' every cell.
#'
#' @param x A `cellspec` object.
#' @param type Plot type: `"overview"`, `"map"`, `"marker"`, `"support"` or
#'   `"area"`.
#' @param colour_by A cells or measurement column that colours the points of
#'   the map. Without it all points have the same colour.
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
#' @param max_panels Largest number of images drawn as separate panels by
#'   the map, the marker plot and the area histogram; the overview uses half
#'   of it, rounded up. With more images, all images share one panel. Subset
#'   the object or raise the value for a larger device.
#' @param ... Reserved for future plot-specific parameters.
#' @return A `ggplot` object, or a patchwork object for `type = "overview"`.
#' @family methods
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' x <- cs_example()
#' plot(x, type = "map")
#' plot(x, type = "marker", marker = "CD3e")
#' plot(x, type = "support")
plot.cellspec <- function(x, type = c("overview", "map", "marker", "support", "area"),
                          colour_by = NULL, marker = NULL, policy = NULL,
                          max_points = 50000L, seed = 1L, max_panels = 12L, ...) {
  call <- rlang::caller_env()
  .cs_check_cellspec(x, call = call)
  .cs_plot_require("ggplot2", minimum = "3.4.0", call = call)
  type <- rlang::arg_match(type)
  .cs_check_count(seed, min = 0L, arg = "seed", call = call)
  .cs_check_count(max_panels, min = 1L, arg = "max_panels", call = call)
  if (type == "map") return(.cs_plot_map(x, colour_by, max_points, seed, call, max_panels))
  if (type == "marker") {
    return(.cs_plot_marker(x, marker, policy, max_points, seed, call, max_panels = max_panels))
  }
  if (type == "support") return(.cs_plot_support(x, call))
  if (type == "area") return(.cs_plot_area(x, call, max_panels))
  .cs_plot_require("patchwork", call = call)
  # Each view has half the width of the device.
  max_panels <- ceiling(max_panels / 2)
  panels <- list(
    .cs_plot_map(x, colour_by, max_points, seed, call, max_panels, compact = TRUE),
    .cs_plot_support(x, call, compact = TRUE)
  )
  if ("area" %in% names(x$cells)) {
    panels <- c(panels, list(.cs_plot_area(x, call, max_panels, compact = TRUE)))
  }
  # Legends below the panels leave the full width to the data; the marker
  # panel already places its own.
  panels <- lapply(panels, function(panel) {
    panel + ggplot2::theme(
      legend.position = "bottom",
      legend.key.width = ggplot2::unit(1.6, "lines")
    )
  })
  if (any(x$dictionary$kind %in% "intensity")) {
    marker_panel <- .cs_plot_marker(
      x, marker, policy, max_points, seed, call, empty_ok = TRUE,
      max_panels = max_panels, compact = TRUE
    )
    if (!is.null(marker_panel)) {
      panels <- c(panels, list(marker_panel))
    }
  }
  patchwork::wrap_plots(panels, ncol = 2)
}
