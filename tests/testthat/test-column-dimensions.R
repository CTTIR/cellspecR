test_that("schema columns reject matrix, array and classed vectors", {
  cases <- list(
    list(component = "cells", column = "x", check = "cells_column_types"),
    list(component = "dictionary", column = "marker", check = "dictionary_column_types"),
    list(component = "images", column = "pixel_size", check = "images_column_types"),
    list(component = "channels", column = "channel_index", check = "channels_column_types")
  )
  for (case in cases) {
    for (dimensions in c(1L, 2L)) {
      x <- cs_example()
      value <- x[[case$component]][[case$column]]
      x[[case$component]][[case$column]] <- matrix(rep(value, dimensions),
                                                 nrow = length(value))
      report <- cs_validate(x)
      expect_identical(report$status[report$check == case$check], "fail")
      expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
    }
  }
  x <- cs_example()
  x$cells$x <- array(x$cells$x, dim = c(nrow(x$cells), 1L, 1L))
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
  x <- cs_example()
  x$cells$x <- structure(x$cells$x, class = "Date")
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
  x <- cs_example()
  x$channels$channel_index <- factor(x$channels$channel_index)
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
})

test_that("dynamic region columns also require dimensionless plain vectors", {
  x <- cs_example()
  x$cells$region__tumour <- matrix(rep("inside", nrow(x$cells)), ncol = 1L)
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
  x$cells$region__tumour <- rep("inside", nrow(x$cells))
  x$cells$boundary_distance__tumour <- matrix(rep(1, nrow(x$cells)), ncol = 1L)
  expect_error(cs_assert_valid(x), class = "cellspec_error_invalid")
})

test_that("invalid extra-column writes preserve canonical destinations", {
  for (format in c("parquet", "tsv.gz")) {
    path <- tempfile("cellspec-dimension-test-")
    withr::defer(unlink(path, recursive = TRUE))
    original <- cs_example()
    cs_write(original, path, format = format)
    before <- cs_verify(path)
    bad <- original
    bad$cells$extra <- cbind(seq_len(nrow(bad$cells)),
                             seq_len(nrow(bad$cells)) + 100L)
    expect_error(cs_write(bad, path, format = format, overwrite = TRUE),
                  class = "cellspec_error_format")
    expect_identical(cs_verify(path), before)
    expect_identical(cs_read_cellspec(path)$cells, original$cells)
    bad$cells$extra <- structure(seq_len(nrow(bad$cells)), class = "Date")
    expect_error(cs_write(bad, path, format = format, overwrite = TRUE),
                  class = "cellspec_error_format")
    expect_identical(cs_verify(path), before)
  }
})
