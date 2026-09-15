test_that("is_cellspec() recognises the class only", {
  expect_true(is_cellspec(cs_example()))
  expect_false(is_cellspec(list()))
  expect_false(is_cellspec(NULL))
})

test_that("print() output is stable and fits in 80 columns", {
  x <- cs_example()
  out <- capture.output(print(x))
  expect_true(all(nchar(out, type = "width") <= 80L))
  expect_snapshot(print(x))
  capture.output(vis <- withVisible(print(x)))
  expect_false(vis$visible)
  expect_snapshot(print(sim_object()))
})

test_that("print() truncates long marker lists and reports mixed pixel sizes", {
  x <- cellspecR:::.cs_simulate(
    n_cells = 5L, n_images = 2L,
    markers = paste0("VeryLongMarkerName", 1:12),
    compartments = "cell"
  )
  x$images$pixel_size[2] <- 0.65
  out <- capture.output(print(x))
  expect_true(all(nchar(out, type = "width") <= 80L))
  expect_match(out[grepl("markers", out)], "\\.\\.\\.$")
  expect_match(out[grepl("pixel", out)], "0.5-0.65 um/px \\(2 values\\)")
})

test_that("print() copes with missing provenance details", {
  p <- min_parts()
  x <- cs_new(p$cells, images = p$images)
  x$provenance$reader$adapter <- NA
  x$images$pixel_size <- NA_real_
  out <- capture.output(print(x))
  expect_match(out[grepl("source", out)], "unknown")
  expect_match(out[grepl("pixel", out)], "unknown")
  expect_match(out[grepl("markers", out)], "none")
})

test_that("summary() returns one row per image with exact values", {
  x <- min_object()
  s <- summary(x)
  expect_s3_class(s, "cellspec_summary")
  expect_named(s, c("image_id", "sample_id", "n_cells", "n_markers", "n_features",
                    "pixel_size", "x_min", "x_max", "y_min", "y_max", "na_fraction"))
  expect_identical(s$n_cells, 3L)
  expect_identical(s$n_markers, 2L)
  expect_identical(s$n_features, 3L)
  expect_identical(s$x_min, 1)
  expect_identical(s$y_max, 6)
  expect_identical(s$na_fraction, 0)
  expect_snapshot(print(s))
})

test_that("summary() counts per-image markers with values and empty images", {
  x <- sim_object(adjacency = FALSE)
  x$measurements[x$cells$image_id == "img2", "cell:FOXP3:mean"] <- NA
  x$measurements[x$cells$image_id == "img2", "nucleus:FOXP3:mean"] <- NA
  s <- summary(x)
  expect_identical(s$n_markers, c(3L, 2L))
  expect_identical(s$n_features, c(9L, 7L))
  expect_equal(s$na_fraction[2], 2 / 9)
  y <- x[x$cells$image_id == "img1", ]
  s2 <- summary(y)
  expect_identical(s2$n_cells, c(12L, 0L))
  expect_true(is.na(s2$x_min[2]))
  expect_true(is.na(s2$na_fraction[2]))
})

test_that("dim() reports cells and features", {
  expect_identical(dim(cs_example()), c(80L, 19L))
  expect_identical(nrow(cs_example()), 80L)
  expect_identical(ncol(cs_example()), 19L)
})

test_that("[ subsets rows by logical, positive and negative indices", {
  x <- sim_object()
  h <- row_hashes(x)
  keep <- x$cells$area > stats::median(x$cells$area)
  expect_identical(row_hashes(x[keep, ]), h[keep])
  expect_identical(row_hashes(x[c(3, 1, 7), ]), h[c(3, 1, 7)])
  expect_identical(row_hashes(x[-(1:5), ]), h[-(1:5)])
  expect_identical(row_hashes(x[, ]), h)
  expect_identical(dim(x[integer(), ]), c(0L, ncol(x)))
  expect_identical(row_hashes(x[c(0, 2), ]), h[2])
  for (y in list(x[keep, ], x[c(3, 1, 7), ], x[-(1:5), ])) {
    expect_true(all(cs_validate(y)$status == "pass"))
  }
})

test_that("[ subsets features and keeps the dictionary aligned", {
  x <- cs_example()
  f <- cs_features(x, marker = "CD3e")
  y <- x[, f]
  expect_identical(colnames(cs_measurements(y)), f)
  expect_identical(cs_dictionary(y)$feature_id, f)
  expect_identical(cs_measurements(y), cs_measurements(x)[, f])
  z <- x[, c(TRUE, FALSE)[rep(1:2, length.out = ncol(x))]]
  expect_identical(cs_dictionary(z)$feature_id, cs_features(x)[seq(1, ncol(x), by = 2)])
  expect_identical(dim(x[1:3, 2]), c(3L, 1L))
  expect_true(all(cs_validate(y)$status == "pass"))
  expect_identical(cs_images(y), cs_images(x))
  expect_identical(cs_channels(y), cs_channels(x))
})

test_that("[ drops adjacency contacts whose cells were removed", {
  x <- sim_object()
  keep <- x$cells$image_id == "img1" & as.integer(x$cells$cell_id) <= 6L
  y <- x[keep, ]
  adj <- cs_adjacency(y)
  expect_true(all(adj$image_id == "img1"))
  expect_true(all(as.integer(adj$cell_id_a) <= 6L & as.integer(adj$cell_id_b) <= 6L))
  expected <- x$adjacency[x$adjacency$image_id == "img1" &
    as.integer(x$adjacency$cell_id_a) <= 6L & as.integer(x$adjacency$cell_id_b) <= 6L, ]
  expect_identical(nrow(adj), nrow(expected))
  expect_true(all(cs_validate(y)$status == "pass"))
})

test_that("[ rejects ambiguous or invalid indices", {
  x <- sim_object()
  expect_snapshot(error = TRUE, {
    x[1]
    x[c(TRUE, FALSE), ]
    x[c(1, 1), ]
    x[c(-1, 2), ]
    x[1000, ]
    x[-1000, ]
    x["c1", ]
    x[, "nope"]
    x[NA_integer_, ]
    x[1.5, ]
  })
  expect_error(x[1, , foo = 1])
})

test_that("[ accepts drop without changing the result", {
  x <- sim_object()
  expect_identical(x[1:2, , drop = TRUE], x[1:2, ])
})

test_that("as.data.frame() combines cells and selected measurements", {
  x <- min_object()
  df <- as.data.frame(x)
  expect_identical(class(df), "data.frame")
  expect_identical(names(df), c(names(cs_cells(x)), cs_features(x)))
  expect_identical(df[["cell:CD3e:mean"]], c(10, 0, 5))
  df2 <- as.data.frame(x, features = "cell:area")
  expect_identical(ncol(df2), ncol(cs_cells(x)) + 1L)
  expect_error(as.data.frame(x, features = "nope"), class = "cellspec_error")
  y <- x
  y$cells[["cell:area"]] <- 1
  expect_error(as.data.frame(y), class = "cellspec_error")
})

test_that("as_tibble() returns a tibble", {
  skip_if_not_installed("tibble")
  x <- min_object()
  tb <- tibble::as_tibble(x, features = "cell:CD3e:mean")
  expect_s3_class(tb, "tbl_df")
  expect_identical(ncol(tb), ncol(cs_cells(x)) + 1L)
})
