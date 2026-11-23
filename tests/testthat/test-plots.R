test_that("plot methods return the expected plot classes", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  map <- plot(x, type = "map", max_points = 12, seed = 7)
  marker <- plot(x, type = "marker", marker = "CD3e")
  support <- plot(x, type = "support")
  area <- plot(x, type = "area")
  expect_s3_class(map, "ggplot")
  expect_s3_class(marker, "ggplot")
  expect_s3_class(support, "ggplot")
  expect_s3_class(area, "ggplot")
  skip_if_not_installed("patchwork")
  expect_s3_class(plot(x, type = "overview"), "patchwork")
})

test_that("plot methods validate requested columns and markers", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  expect_error(
    plot(x, type = "map", colour_by = "missing"),
    class = "cellspec_error_invalid"
  )
  expect_error(
    plot(x, type = "marker", marker = "missing"),
    class = "cellspec_error_invalid"
  )
  expect_error(
    plot(x, type = "map", max_points = 0),
    class = "cellspec_error"
  )
})

test_that("plot helpers cover numeric, policy and empty-data paths", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  expect_s3_class(
    cellspecR:::.cs_plot_map(
      x, colour_by = "cell:CD3e:mean", max_points = 3L, seed = 2L,
      call = rlang::caller_env()
    ),
    "ggplot"
  )
  policy <- cs_signal_policy("CD3e", compartment = "cell")
  selected <- cellspecR:::.cs_plot_signal_long(
    x, marker = "CD3e", policy = policy, call = rlang::caller_env()
  )
  expect_true(nrow(selected) > 0L)
  expect_error(
    cellspecR:::.cs_plot_signal_long(
      x, marker = "missing", call = rlang::caller_env()
    ),
    class = "cellspec_error"
  )
  no_area <- x
  no_area$cells$area <- NULL
  expect_error(
    cellspecR:::.cs_plot_area(no_area, rlang::caller_env()),
    class = "cellspec_error"
  )
  expect_identical(
    cellspecR:::.cs_plot_subsample(x$cells, 1000L, 1L, rlang::caller_env()),
    seq_len(nrow(x$cells))
  )
})

test_that("the marker plot shows each source with its own values", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  data <- plot(x, type = "marker", marker = "CD3e")$data
  features <- cs_features(x, kind = "intensity", marker = "CD3e")
  # One row per cell and source; values used to be repeated and mislabelled.
  expect_identical(nrow(data), nrow(x) * length(features))
  expect_identical(unique(data$marker), "CD3e")
  for (feature in features) {
    entry <- x$dictionary[x$dictionary$feature_id == feature, ]
    shown <- data[data$compartment == entry$compartment &
      data$statistic == entry$statistic, ]
    expect_identical(shown$value, unname(x$measurements[, feature]))
    expect_identical(shown$image_id, x$cells$image_id)
  }
  expect_identical(
    sort(unique(data$source)),
    c("cell:mean", "cell:median", "nucleus:mean", "nucleus:median")
  )
})

test_that("the marker plot defaults to the first marker and names it", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  default <- plot(x, type = "marker")
  expect_identical(unique(default$data$marker), cs_markers(x)[[1L]])
  expect_identical(default$labels$title, cs_markers(x)[[1L]])
  expect_identical(default$data, plot(x, type = "marker", marker = "DAPI")$data)

  policy <- cs_signal_policy(c("FOXP3", "CD3e"), compartment = "nucleus")
  selected <- plot(x, type = "marker", policy = policy)$data
  expect_identical(unique(selected$marker), "FOXP3")
  expect_identical(unique(selected$source), "selected")
  expect_identical(selected$value, unname(x$measurements[, "nucleus:FOXP3:mean"]))
  # A policy that does not cover the marker leaves the sources as they are.
  raw <- plot(x, type = "marker", marker = "DAPI", policy = policy)$data
  expect_false("selected" %in% raw$source)
})

test_that("the marker plot subsamples large objects reproducibly", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  first <- plot(x, type = "marker", marker = "CD3e", max_points = 10, seed = 3)$data
  again <- plot(x, type = "marker", marker = "CD3e", max_points = 10, seed = 3)$data
  expect_identical(first, again)
  expect_identical(nrow(first), 10L * 4L)
  expect_error(
    plot(x, type = "marker", max_points = 0),
    class = "cellspec_error"
  )
})

test_that("plots of objects without cells or signal fail clearly or leave panels out", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  empty <- x[0, ]
  expect_error(plot(empty, type = "marker"), class = "cellspec_error_invalid")
  blank <- x
  blank$measurements[, cs_features(x, marker = "CD3e")] <- NA_real_
  expect_error(
    plot(blank, type = "marker", marker = "CD3e"),
    class = "cellspec_error_invalid"
  )
  no_features <- x[, 0]
  expect_error(plot(no_features, type = "marker"), class = "cellspec_error_invalid")
  for (type in c("map", "support", "area")) {
    expect_no_error(ggplot2::ggplot_build(plot(empty, type = type)))
  }
  skip_if_not_installed("patchwork")
  expect_length(plot(x, type = "overview")$patches$plots, 3L)
  expect_length(plot(empty, type = "overview")$patches$plots, 2L)
  expect_length(plot(no_features, type = "overview")$patches$plots, 2L)
  # An unknown marker is still an error in the overview.
  expect_error(
    plot(x, type = "overview", marker = "missing"),
    class = "cellspec_error_invalid"
  )
})

test_that("the map keeps the image frame with y increasing downwards", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  map <- plot(x, type = "map")
  expect_identical(map$data$y, x$cells$y)
  expect_identical(map$labels$y, "y (µm)")
  y_scale <- ggplot2::ggplot_build(map)$layout$panel_scales_y[[1L]]
  # ggplot2 3.5.0 renamed the scale field `trans` to `transformation`.
  transformation <- if (is.null(y_scale$transformation)) y_scale$trans else y_scale$transformation
  expect_identical(transformation$name, "reverse")
})

test_that("the map and the area histogram draw one panel per image", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  images <- x$images$image_id
  for (type in c("map", "area")) {
    built <- ggplot2::ggplot_build(plot(x, type = type))
    expect_identical(as.character(built$layout$layout$image_id), images)
    # Without a colour column there is nothing to explain in a legend: the
    # built plot has no colour or fill scale.
    aesthetics <- unlist(lapply(built$plot$scales$scales, function(scale) scale$aesthetics))
    expect_false(any(c("colour", "fill") %in% aesthetics))
  }
  coloured_scales <- ggplot2::ggplot_build(plot(x, type = "map", colour_by = "image_id"))$plot$scales
  expect_true("colour" %in% unlist(lapply(coloured_scales$scales, function(scale) scale$aesthetics)))
  map <- plot(x, type = "map")
  expect_identical(map$data$image_id, x$cells$image_id)
  expect_false("colour" %in% names(map$data))
  coloured <- plot(x, type = "map", colour_by = "image_id")
  expect_identical(coloured$data$colour, x$cells$image_id)
  expect_identical(coloured$labels$colour, "image_id")
  numeric <- plot(x, type = "map", colour_by = "cell:CD3e:mean")
  expect_identical(numeric$data$colour, unname(x$measurements[, "cell:CD3e:mean"]))
})

test_that("image panels follow the images table and are pooled above max_panels", {
  skip_if_not_installed("ggplot2")
  panels <- function(p) ggplot2::ggplot_build(p)$layout$layout
  twelve <- cellspecR:::.cs_simulate(n_cells = 5L, n_images = 12L)
  ids <- twelve$images$image_id
  expect_identical(ids[c(2L, 10L)], c("img2", "img10"))
  for (type in c("map", "marker", "area")) {
    layout <- panels(plot(twelve, type = type))
    # Not alphabetical: img2 comes before img10.
    expect_identical(as.character(layout$image_id), ids)
    expect_null(plot(twelve, type = type)$labels$subtitle)
  }
  support <- ggplot2::ggplot_build(plot(twelve, type = "support"))
  expect_identical(support$layout$panel_scales_x[[1L]]$get_limits(), ids)

  many <- cellspecR:::.cs_simulate(n_cells = 5L, n_images = 13L)
  for (type in c("map", "marker", "area")) {
    pooled <- plot(many, type = type)
    expect_identical(nrow(panels(pooled)), 1L)
    expect_identical(pooled$labels$subtitle, "13 images pooled in one panel")
    expect_identical(nrow(panels(plot(many, type = type, max_panels = 13))), 13L)
    expect_identical(nrow(panels(plot(twelve, type = type, max_panels = 11))), 1L)
  }
  # The pooled map still has the image frame.
  y_scale <- ggplot2::ggplot_build(plot(many, type = "map"))$layout$panel_scales_y[[1L]]
  transformation <- if (is.null(y_scale$transformation)) y_scale$trans else y_scale$transformation
  expect_identical(transformation$name, "reverse")

  # The overview gives each view half the width and pools above half the number.
  skip_if_not_installed("patchwork")
  six <- cellspecR:::.cs_simulate(n_cells = 5L, n_images = 6L)
  seven <- cellspecR:::.cs_simulate(n_cells = 5L, n_images = 7L)
  overview_panels <- function(x, ...) {
    overview <- plot(x, ...)
    views <- c(overview$patches$plots, list(overview))
    vapply(views[c(1L, 3L, 4L)], function(view) nrow(panels(view)), integer(1))
  }
  expect_identical(overview_panels(six), c(6L, 6L, 6L))
  expect_identical(overview_panels(seven), c(1L, 1L, 1L))
  expect_identical(overview_panels(seven, max_panels = 14), c(7L, 7L, 7L))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_warning(print(plot(many)))

  expect_error(plot(six, type = "map", max_panels = 0), class = "cellspec_error")
  expect_error(plot(six, max_panels = 1.5), class = "cellspec_error")
})

test_that("the support heatmap reads from top to bottom and separates its tiles", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  support <- plot(x, type = "support")
  built <- ggplot2::ggplot_build(support)
  labels <- built$layout$panel_scales_y[[1L]]$get_limits()
  expect_identical(labels, rev(sort(unique(support$data$label))))
  expect_identical(unique(built$data[[1L]]$colour), "white")
})

test_that("the marker plot draws an image with a single cell without warnings", {
  skip_if_not_installed("ggplot2")
  x <- cs_example()
  keep <- c(which(x$cells$image_id == "img1"), which(x$cells$image_id == "img2")[[1L]])
  marker <- plot(x[keep, ], type = "marker", marker = "CD3e")
  expect_no_warning(built <- ggplot2::ggplot_build(marker))
  # Violin and box for img1, a point per source for the single cell of img2.
  single <- marker$data[marker$data$single, , drop = FALSE]
  expect_identical(unique(single$image_id), "img2")
  expect_identical(nrow(built$data[[3L]]), nrow(single))
  expect_no_warning(ggplot2::ggplot_build(plot(x[1L, ], type = "marker")))
})

test_that("plotting reports a ggplot2 version below the declared minimum", {
  skip_if_not_installed("ggplot2")
  expect_true(cellspecR:::.cs_plot_require("ggplot2", minimum = "3.4.0"))
  expect_error(
    cellspecR:::.cs_plot_require("ggplot2", minimum = "999.0.0"),
    "999.0.0 or later",
    class = "cellspec_error_format"
  )
})
