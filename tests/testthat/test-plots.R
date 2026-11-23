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
