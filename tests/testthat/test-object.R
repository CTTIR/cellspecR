test_that("cs_new() builds a valid object from minimal inputs", {
  x <- min_object()
  expect_s3_class(x, "cellspec")
  expect_identical(x$spec_version, cs_spec_version())
  expect_named(x, c("spec_version", "cells", "measurements", "dictionary",
                    "images", "channels", "provenance", "adjacency"))
  expect_true(all(cs_validate(x)$status == "pass"))
  expect_null(cs_adjacency(x))
})

test_that("cs_new() works without measurements, dictionary or channels", {
  p <- min_parts()
  x <- cs_new(p$cells, images = p$images)
  expect_identical(dim(x), c(3L, 0L))
  expect_identical(nrow(cs_dictionary(x)), 0L)
  expect_identical(nrow(cs_channels(x)), 0L)
  expect_named(cs_channels(x), c("image_id", "channel_index", "channel_name", "marker"))
})

test_that("cs_new() requires cells and images", {
  p <- min_parts()
  expect_error(cs_new(images = p$images), "cells")
  expect_error(cs_new(p$cells), "images")
})

test_that("cs_new() normalises identifiers, factors, types and row names", {
  p <- min_parts()
  p$cells$cell_id <- c(101, 102, 103)
  p$cells$image_id <- factor(p$cells$image_id)
  p$cells$x <- 1:3
  rownames(p$cells) <- c("a", "b", "c")
  p$channels$channel_index <- c(1, 2, 3)
  p$images$width_px <- 100
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  expect_identical(cs_cells(x)$cell_id, c("101", "102", "103"))
  expect_identical(cs_cells(x)$image_id, rep("img1", 3))
  expect_type(cs_cells(x)$x, "double")
  expect_identical(attr(cs_cells(x), "row.names"), 1:3)
  expect_type(cs_channels(x)$channel_index, "integer")
  expect_type(cs_images(x)$width_px, "integer")
})

test_that("cs_new() formats large numeric identifiers without scientific notation", {
  p <- min_parts()
  p$cells$cell_id <- c(1e6, 2e6, 123456789012)
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  expect_identical(cs_cells(x)$cell_id, c("1000000", "2000000", "123456789012"))
})

test_that("cs_new() accepts tibbles, data.tables and measurement data frames", {
  skip_if_not_installed("tibble")
  p <- min_parts()
  x <- cs_new(
    tibble::as_tibble(p$cells),
    as.data.frame(p$measurements),
    data.table::as.data.table(p$dictionary),
    p$images,
    p$channels
  )
  expect_identical(class(cs_cells(x)), "data.frame")
  expect_identical(class(cs_dictionary(x)), "data.frame")
  expect_true(is.matrix(cs_measurements(x)))
  expect_type(cs_measurements(x), "double")
})

test_that("cs_new() fills sample_id from images", {
  p <- min_parts()
  p$cells$sample_id <- NULL
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  expect_identical(cs_cells(x)$sample_id, rep("s1", 3))
})

test_that("cs_new() converts non-finite measurements to NA and counts them", {
  p <- min_parts()
  p$measurements[1, 1] <- Inf
  p$measurements[2, 2] <- NaN
  p$measurements[3, 2] <- NA
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  m <- cs_measurements(x)
  expect_true(is.na(m[1, 1]))
  expect_true(is.na(m[2, 2]) && !is.nan(m[2, 2]))
  expect_identical(cs_provenance(x)$counts$nonfinite_converted, 2L)
})

test_that("cs_new() converts integer and logical measurement matrices to double", {
  p <- min_parts()
  storage.mode(p$measurements) <- "integer"
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  expect_type(cs_measurements(x), "double")
})

test_that("cs_new() rejects malformed inputs with informative errors", {
  p <- min_parts()
  expect_snapshot(error = TRUE, {
    cs_new(p$cells, p$measurements, NULL, p$images, p$channels)
    cs_new(list(1), images = p$images)
    cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels, provenance = "x")
    cs_new(p$cells, data.frame(a = "x"), p$dictionary, p$images, p$channels)
    cs_new(p$cells, "x", p$dictionary, p$images, p$channels)
    cs_new(p$cells, unname(p$measurements), p$dictionary, p$images, p$channels)
  })
})

test_that("cs_new() aborts with cellspec_error_invalid on rule violations", {
  p <- min_parts()
  p$cells$cell_id[2] <- "c1"
  expect_error(
    cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels),
    class = "cellspec_error_invalid"
  )
  cnd <- rlang::catch_cnd(
    cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels),
    classes = "cellspec_error"
  )
  expect_s3_class(cnd$report, "cellspec_validation")
  expect_snapshot(error = TRUE, {
    cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels)
  })
})

test_that("cs_new() keeps supplied provenance and fills missing fields", {
  p <- min_parts()
  prov <- list(producer = list(tool = "QuPath", version = "0.7.0"), parameters = list(a = 1))
  x <- cs_new(p$cells, p$measurements, p$dictionary, p$images, p$channels, provenance = prov)
  pr <- cs_provenance(x)
  expect_identical(pr$producer$tool, "QuPath")
  expect_identical(pr$parameters$a, 1)
  expect_named(pr, c("producer", "parameters", "reader", "created_utc", "inputs", "counts", "history"), ignore.order = TRUE)
  expect_identical(pr$reader$package, "cellspecR")
})

test_that("default provenance records the creation step", {
  pr <- cs_provenance(min_object())
  expect_identical(pr$reader$adapter, "cs_new")
  expect_length(pr$history, 1L)
  expect_identical(pr$history[[1]][["function"]], "cs_new")
  expect_match(pr$created_utc, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})

test_that("accessors return components and reject other objects", {
  x <- sim_object()
  expect_identical(cs_cells(x), x$cells)
  expect_identical(cs_measurements(x), x$measurements)
  expect_identical(cs_dictionary(x), x$dictionary)
  expect_identical(cs_images(x), x$images)
  expect_identical(cs_channels(x), x$channels)
  expect_identical(cs_provenance(x), x$provenance)
  expect_identical(cs_adjacency(x), x$adjacency)
  for (f in list(cs_cells, cs_measurements, cs_dictionary, cs_images,
                 cs_channels, cs_provenance, cs_adjacency, cs_markers)) {
    expect_error(f(data.frame()), class = "cellspec_error")
  }
  expect_snapshot(error = TRUE, cs_cells(list()))
})

test_that("cs_features() filters by dictionary columns", {
  x <- cs_example()
  expect_identical(
    cs_features(x, kind = "intensity", marker = "FOXP3", statistic = "mean"),
    c("cell:FOXP3:mean", "nucleus:FOXP3:mean")
  )
  expect_identical(cs_features(x, kind = "shape"), c("cell:area", "nucleus:area"))
  expect_identical(cs_features(x), cs_dictionary(x)$feature_id)
  expect_identical(cs_features(x, marker = "nope"), character())
  expect_identical(
    cs_features(x, compartment = c("nucleus"), statistic = c("median")),
    c("nucleus:DAPI:median", "nucleus:CD3e:median", "nucleus:Pan-Cytokeratin:median", "nucleus:FOXP3:median")
  )
  expect_error(cs_features(x, marker = 1), class = "cellspec_error")
})

test_that("cs_markers() lists intensity markers in order of appearance", {
  expect_identical(cs_markers(cs_example()), c("DAPI", "CD3e", "Pan-Cytokeratin", "FOXP3"))
  p <- min_parts()
  expect_identical(cs_markers(cs_new(p$cells, images = p$images)), character())
})

test_that("cs_example() is deterministic and leaves the RNG state alone", {
  set.seed(99)
  before <- .Random.seed
  a <- cs_example()
  expect_identical(.Random.seed, before)
  b <- cs_example()
  expect_identical(a, b)
  expect_identical(dim(a), c(80L, 19L))
})

test_that("cs_example() works when no seed exists yet", {
  had <- exists(".Random.seed", envir = globalenv())
  if (had) {
    old <- get(".Random.seed", envir = globalenv())
    rm(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  }
  x <- cs_example()
  expect_false(exists(".Random.seed", envir = globalenv()))
  expect_s3_class(x, "cellspec")
})
