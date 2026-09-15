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
