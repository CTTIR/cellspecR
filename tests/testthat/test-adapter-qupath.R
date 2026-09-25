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

test_that("compartment morphology preserves cell area and nuclear shapes", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  for (unit in c("um", "\u00b5m", "\u03bcm", "\u00c2\u00b5m")) {
    data <- data.frame(cell_id = c("a", "b"), centroid_x_um = c(1, 2),
                       centroid_y_um = c(3, 4), check.names = FALSE)
    data[[paste0("Nucleus: Area ", unit, "^2")]] <- c(4, 8)
    data[[paste0("Cell: Area ", unit, "^2")]] <- c(10, 20)
    data[[paste0("Nucleus: Length ", unit)]] <- c(6, 12)
    data[["Cell: Circularity"]] <- c(0.5, 0.7)
    data[["Nucleus/Cell area ratio"]] <- c(0.4, 0.4)
    data[["Cell: CD3e: Mean"]] <- c(0, NA_real_)
    data.table::fwrite(data, path)
    x <- cs_read(path, format = "qupath", quiet = TRUE)
    expect_identical(x$cells$area, c(10, 20))
    expect_identical(x$measurements[, "nucleus:area"], c(4, 8))
    expect_identical(x$measurements[, "cell:CD3e:mean"], c(0, NA_real_))
    expect_identical(x$dictionary$source_name, names(data)[c(4, 6:9)])
    expect_identical(x$dictionary$unit, c("um2", "um", "1", "1", "a.u."))
    expect_identical(x$provenance$reader$adapter_version, "1.0.1")
  }
})

test_that("a complete synthetic compartment export preserves area and intensities", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  data <- data.frame(sample = "synthetic", cell_id = "a", centroid_x_px = 2,
                     centroid_y_px = 4, centroid_x_um = 1, centroid_y_um = 2)
  shapes <- c("Area um^2", "Length um", "Circularity", "Solidity",
              "Max diameter um", "Min diameter um")
  for (compartment in c("Nucleus", "Cell")) {
    for (shape in shapes) data[[paste0(compartment, ": ", shape)]] <- 10
  }
  data[["Nucleus/Cell area ratio"]] <- 1
  for (compartment in c("Nucleus", "Cell", "Cytoplasm", "Membrane")) {
    for (marker in paste0("Channel", seq_len(18))) {
      for (stat in c("Mean", "Median", "Std.Dev.", "Max", "Min")) {
        data[[paste(compartment, marker, stat, sep = ": ")]] <- 7
      }
    }
  }
  expect_equal(ncol(data), 379)
  data.table::fwrite(data, path)
  x <- cs_read(path, format = "qupath", pixel_size = 0.5, quiet = TRUE)
  expect_identical(x$cells$area, 10)
  expect_equal(sum(x$dictionary$kind == "shape"), 12)
  expect_equal(ncol(x$measurements), 374)
  expect_true(all(x$measurements[, x$dictionary$kind == "intensity"] == 7))
  expect_identical(x$cells$cell_id, "a")
  expect_identical(x$cells$x, 1)
  expect_identical(x$cells$y, 2)
})

test_that("shape grammar is conservative about dimensions and compartments", {
  parse <- cellspecR:::.cs_qupath_shape_metadata
  expect_null(parse("Unknown: Area um2"))
  expect_null(parse("Cell: unknown: shape"))
  expect_null(parse("Cell: Area"))
  expect_null(parse("Cell: Length"))
  expect_null(parse("Cell: Circularity um"))
  expect_null(parse("Cell: novel score"))
  expect_identical(parse("Nucleus: Area px^2")$unit, "px2")
  expect_identical(parse("Cell: Perimeter px")$unit, "px")
  expect_identical(parse("Area um2")$compartment, "cell")
  map <- cellspecR:::.cs_qupath_map(
    c("cell_id", "centroid_x_um", "centroid_y_um", "Nucleus: Area um2")
  )
  expect_null(map$area)
  expect_identical(map$measurements$compartment, "nucleus")
})

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
