qupath_fixture <- function(path, units = "um") {
  if (units == "um") {
    data <- data.frame(
      `Cell ID` = c("a", "b"),
      `Centroid X um` = c(10, 20),
      `Centroid Y um` = c(30, 40),
      `Area µm^2` = c(25, 30),
      `DAPI: Mean` = c(100, 110),
      `Nucleus: CD3e: Mean` = c(5, 9),
      `Cell Type` = c("T", "B"),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  } else {
    data <- data.frame(
      `Cell ID` = c("a", "b"),
      `Centroid X px` = c(2, 4),
      `Centroid Y px` = c(6, 8),
      `DAPI: Mean` = c(100, 110),
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  data.table::fwrite(data, path, sep = "\t", quote = FALSE)
  invisible(path)
}

test_that("QuPath channel-first and compartment-first headers map correctly", {
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  qupath_fixture(path)

  expect_identical(cellspecR:::cs_detect_format(path)$format[[1L]], "qupath")
  x <- cellspecR:::cs_read(path, format = "qupath")

  expect_s3_class(x, "cellspec")
  expect_identical(x$cells$cell_id, c("a", "b"))
  expect_identical(x$cells$x, c(10, 20))
  expect_identical(x$cells$area, c(25, 30))
  expect_identical(colnames(x$measurements), c("cell:DAPI:mean", "nucleus:CD3e:mean"))
  expect_identical(x$measurements[, "cell:DAPI:mean"], c(100, 110))
  expect_identical(x$dictionary$source_name, c("DAPI: Mean", "Nucleus: CD3e: Mean"))
  expect_identical(x$cells$`Cell Type`, c("T", "B"))
  expect_identical(x$provenance$reader$adapter, "qupath")
})

test_that("QuPath marker maps are applied without losing source names", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  qupath_fixture(path)
  map <- cellspecR::cs_marker_map("CD3e", "CD3")

  x <- cellspecR:::cs_read(path, format = "qupath", marker_map = map)
  expect_true("nucleus:CD3:mean" %in% colnames(x$measurements))
  expect_identical(x$dictionary$marker_source, c(NA_character_, NA_character_))
  expect_identical(x$dictionary$source_name[[2L]], "Nucleus: CD3e: Mean")
  expect_identical(x$dictionary$marker[[2L]], "CD3")
})

test_that("QuPath pixel coordinates require and use calibration", {
  path <- tempfile(fileext = ".tsv")
  on.exit(unlink(path), add = TRUE)
  qupath_fixture(path, units = "px")

  expect_error(
    cellspecR:::cs_read(path, format = "qupath"),
    class = "cellspec_error_units"
  )
  x <- cellspecR:::cs_read(path, format = "qupath", pixel_size = 0.5)
  expect_identical(x$cells$x, c(1, 2))
  expect_identical(x$cells$y, c(3, 4))
  expect_identical(x$cells$x_px, c(2, 4))
})

test_that("QuPath reader refuses missing identifiers and missing coordinate units", {
  missing_id <- tempfile(fileext = ".csv")
  on.exit(unlink(missing_id), add = TRUE)
  data.table::fwrite(data.frame(x = 1, y = 2, `DAPI: Mean` = 3), missing_id)
  expect_error(
    cellspecR:::cs_read(missing_id, format = "qupath"),
    class = "cellspec_error_format"
  )

  missing_units <- tempfile(fileext = ".csv")
  on.exit(unlink(missing_units), add = TRUE)
  data.table::fwrite(data.frame(`Cell ID` = "a", x = 1, y = 2,
                                check.names = FALSE), missing_units)
  expect_error(
    cellspecR:::cs_read(missing_units, format = "qupath"),
    class = "cellspec_error_units"
  )
})
